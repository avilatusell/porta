# frozen_string_literal: true

class Admin::Api::Registry::PoliciesController < Admin::Api::BaseController
  clear_respond_to
  respond_to :json

  representer ::Policy


  # swagger
  ##~ sapi = source2swagger.namespace("Account Management API")
  ##~ e = sapi.apis.add
  ##~ e.path = "/admin/api/registry/policies.json"
  ##~ e.responseClass = "policy"
  #
  ##~ op            = e.operations.add
  ##~ op.httpMethod = "POST"
  ##~ op.summary    = "APIcast Policy Registry Create"
  ##~ op.description = "Creates an APIcast Policy"
  ##~ op.group = "apicast_policies"
  #
  ##~ op.parameters.add @parameter_access_token
  ##~ op.parameters.add :name => "name", :description => "Name of the policy", :required => true, :dataType => "string", :paramType => "query"
  ##~ op.parameters.add :name => "version", :description => "Version of the policy", :required => true, :dataType => "string", :paramType => "query"
  ##~ op.parameters.add :name => "schema", :description => "JSON Schema of the policy", :required => true, :dataType => "string", :paramType => "query"
  #
  def create
    respond_with current_account.policies.create(policy_params)
  end

  private

  def policy_params
    params.require(:policy).permit(:name, :version, :schema)
  end
end
