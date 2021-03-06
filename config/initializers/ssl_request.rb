# frozen_string_literal: true

if Rails.application.config.force_ssl
  apicast_regexp = Regexp.compile(Rails.configuration.three_scale.apicast_internal_host_regexp.presence || '\A(?!.*)\Z')

  internal_request = ->(request) { apicast_regexp.match(request.host) || PrometheusExporterPort.call == request.port }
  Rails.application.config.ssl_options = { redirect: { exclude: internal_request } }
end
