require 'simplecov'
require 'simplecov_json_formatter'
SimpleCov.start do
  formatter SimpleCov::Formatter::JSONFormatter
end

require 'minitest/autorun'
require 'timecop'
require File.expand_path './support/vcr_setup.rb', __dir__

require 'loop'
require 'config'

# Silence deprecation warnings caused by the `influxdb-client` gem
Warning[:deprecated] = false
