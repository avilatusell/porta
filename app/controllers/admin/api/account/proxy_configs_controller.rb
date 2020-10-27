# frozen_string_literal: true

class Admin::Api::Account::ProxyConfigsController < Admin::Api::BaseController
  include ApiAuthentication::BySsoToken

  represents :json, entity: ::ProxyConfigRepresenter
  represents :json, collection: ::ProxyConfigsRepresenter

  clear_respond_to
  respond_to :json

  rescue_from(ProxyConfig::InvalidEnvironmentError) do
    render_error 'invalid environment', status: :unprocessable_entity
  end

  ##~ e = sapi.apis.add
  ##~ e.path = "/admin/api/account/proxy_configs/{environment}.json"
  ##~ e.responseClass = "proxy_config"
  #
  ##~ op             = e.operations.add
  ##~ op.httpMethod  = "GET"
  ##~ op.summary     = "Proxy Configs List (Provider)"
  ##~ op.description = "Returns the Proxy Configs of the provider"
  ##~ op.group       = "proxy_config"
  #
  ##~ op.parameters.add @parameter_access_token
  ##~ op.parameters.add @parameter_environment
  #
  def index
    respond_with proxy_configs.order(:id).paginate(pagination_params)
  end

  private

  def proxy_configs
    ProxyConfig.where(proxy_id: accessible_proxies_ids).by_environment(environment)
  end

  def accessible_proxies_ids
    @accessible_proxies_ids ||= begin
      oracle_adapter = System::Database.oracle?
      accessible_services_ids = oracle_adapter ? accessible_services.pluck(:id) : accessible_services.select(:id)
      accessible_proxies = Proxy.where(service_id: accessible_services_ids)
      oracle_adapter ? accessible_proxies.pluck(:id) : accessible_proxies.select(:id)
    end
  end

  def accessible_services
    (current_user || current_account).accessible_services
  end

  def environment
    params.require(:environment)
  end
end
