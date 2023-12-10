require 'test_helper'
require 'senec_pull'
require 'config'

class SenecPullTest < Minitest::Test
  def test_next_success
    VCR.use_cassette('senec_success') do
      response = senec_pull.next

      assert_includes 0..100, response[:bat_fuel_charge]
      assert_includes [0, 1], response[:safe_charge_running]
    end
  end

  def test_next_failure
    Senec::Local::Request.stub :new, ->(_args) { raise Senec::Local::Error } do
      assert_raises(Senec::Local::Error) { senec_pull.next }
    end
  end

  private

  def config
    @config ||= Config.from_env
  end

  def senec_pull
    SenecPull.new(config:)
  end
end
