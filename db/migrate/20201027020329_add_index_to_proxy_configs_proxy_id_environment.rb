# frozen_string_literal: true

class AddIndexToProxyConfigsProxyIdEnvironment < ActiveRecord::Migration[5.0]
  disable_ddl_transaction!

  def change
    index_options = {}
    index_options[:algorithm] = :concurrently if System::Database.postgres?
    add_index :proxy_configs, %i[proxy_id environment], index_options
  end
end
