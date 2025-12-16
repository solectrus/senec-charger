require 'minitest/autorun'
require 'minitest/spec'
require 'webmock/minitest'
require 'vcr'
require 'timecop'
require 'dotenv'

Dotenv.load('.env.test')

# 1. Add 'app' folder to the Load Path
# This ensures that if code inside app/ uses "require 'config'", it works.
$LOAD_PATH.unshift File.expand_path('../app', __dir__)

# 2. Load Application Files using require_relative
# We use require_relative here because it is stricter and safer than 'require'.
# It guarantees finding the file relative to this test_helper.
require_relative '../app/config'
require_relative '../app/senec_provider'
require_relative '../app/prices_provider'
require_relative '../app/forecast_provider'
require_relative '../app/battery_action'
require_relative '../app/loop'

# --- VCR Config ---
VCR.configure do |config|
  config.cassette_library_dir = 'test/cassettes'
  config.hook_into :webmock
end