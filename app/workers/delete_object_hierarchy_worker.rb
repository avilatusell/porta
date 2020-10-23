# frozen_string_literal: true

class DeleteObjectHierarchyWorker < ApplicationJob
  include Sidekiq::Throttled::Worker

  # TODO: Rails 5 --> discard_on ActiveJob::DeserializationError
  # No need of ActiveRecord::RecordNotFound because that can only happen in the callbacks and those callbacks don't use this rescue_from but its own rescue
  rescue_from(ActiveJob::DeserializationError, DeletionLock::LockDeletionError) do |exception|
    Rails.logger.info "DeleteObjectHierarchyWorker#perform raised #{exception.class} with message #{exception.message}"
  end

  queue_as :deletion

  sidekiq_throttle({
                     concurrency: { limit: 15 },
                     threshold:   { limit: 40_000, period: 1.minute }
                   })

  before_perform do |job|
    @object, workers_hierarchy, @options = job.arguments
    @id = "Hierarchy-#{object.class.name}-#{object.id}"
    @caller_worker_hierarchy = Array(workers_hierarchy) + [id]
    info "Starting #{job.class}#perform with the hierarchy of workers: #{caller_worker_hierarchy}"
  end

  after_perform do |job|
    info "Finished #{job.class}#perform with the hierarchy of workers: #{caller_worker_hierarchy}"
  end

  def perform(_object, _caller_worker_hierarchy = [], _options = {})
    if lock?
      DeletionLock.call_with_lock(lock_key: id, debug_info: caller_worker_hierarchy) { build_batch }
    else
      build_batch
    end
  end

  def on_success(_, options)
    on_finish('on_success', options)
  end

  def on_complete(_, options)
    on_finish('on_complete', options)
  end

  def on_finish(method_name, options)
    workers_hierarchy = options['caller_worker_hierarchy']
    info "Starting DeleteObjectHierarchyWorker##{method_name} with the hierarchy of workers: #{workers_hierarchy}"
    object = GlobalID::Locator.locate(options['object_global_id'])
    DeletePlainObjectWorker.perform_later(object, workers_hierarchy, background_destroy_method)
    info "Finished DeleteObjectHierarchyWorker##{method_name} with the hierarchy of workers: #{workers_hierarchy}"
  rescue ActiveRecord::RecordNotFound => exception
    info "DeleteObjectHierarchyWorker##{method_name} raised #{exception.class} with message #{exception.message}"
  end

  protected

  def background_destroy_method
    options.fetch(:background_destroy_method) { ::BackgroundDeletion::Reflection::DEFAULT_DESTROY_METHOD }
  end

  def lock?
    options.fetch(:lock) { ::BackgroundDeletion::Reflection::DEFAULT_LOCK_OPTION }
  end

  delegate :info, to: 'Rails.logger'

  attr_reader :object, :caller_worker_hierarchy, :id, :options

  def build_batch
    batch = Sidekiq::Batch.new
    batch.description = batch_description
    batch_callbacks(batch) { batch.jobs { destroy_and_delete_associations } }
    batch
  end

  def batch_description
    "Deleting #{object.class.name} [##{object.id}]"
  end

  def batch_callbacks(batch)
    %i[success complete].each { |name| batch.on(name, self.class, callback_options) }
    yield
    bid = batch.bid

    if Sidekiq::Batch::Status.new(bid).total.zero?
      on_complete(bid, callback_options)
    else
      info("DeleteObjectHierarchyWorker#batch_success_callback retry job with the hierarchy of workers: #{caller_worker_hierarchy}")
      retry_job wait: 5.minutes
    end
  end

  def destroy_and_delete_associations
    Array(object.background_deletion).each do |association_config|
      reflection = BackgroundDeletion::Reflection.new(association_config)
      next unless destroyable_association?(reflection.name)

      Deletion::ReflectionDestroyerService.call(object, reflection, caller_worker_hierarchy)
    end
  end

  def destroyable_association?(_association)
    true
  end

  private

  def called_from_provider_hierarchy?
    return unless (tenant_id = object.tenant_id)

    caller_worker_hierarchy.include?("Hierarchy-Account-#{tenant_id}")
  end

  def callback_options
    { 'object_global_id' => object.to_global_id, 'caller_worker_hierarchy' => caller_worker_hierarchy }
  end
end
