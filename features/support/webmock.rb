# frozen_string_literal: true

require 'webmock/cucumber'
WebMock.disable_net_connect!(allow_localhost: true, allow: [/\.example\.com/, /__identify__/])
