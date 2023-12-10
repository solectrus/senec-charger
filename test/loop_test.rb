require 'test_helper'
require 'loop'
require 'config'

class LoopTest < Minitest::Test
  def test_start_successful
    config = Config.from_env

    cassettes = [{ name: 'loop_success' }]

    out, err =
      capture_io do
        VCR.use_cassettes(cassettes) { Loop.start(config:, max_count: 2) }
      end

    assert_match(/Fetching data from SENEC/, out)
    assert_match(/Fetchting data from InfluxDB/, out)
    assert_empty(err)
  end
end
