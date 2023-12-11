require 'simplecov'
SimpleCov.start

require 'minitest/autorun'
require 'timecop'
require File.expand_path './support/vcr_setup.rb', __dir__
