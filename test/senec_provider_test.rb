require 'test_helper'
require 'senec_provider'
require 'config'

class SenecProviderTest < Minitest::Test
  def test_success_request
    VCR.use_cassette('senec_success') do
      assert_includes 0..100, senec_provider.bat_fuel_charge
      assert_includes [false, true], senec_provider.safe_charge_running?
      assert_nil senec_provider.bat_fuel_charge_increased?
    end
  end

  def test_stale_request
    VCR.use_cassette('senec_success') do
      assert_includes 0..100, senec_provider.bat_fuel_charge

      Timecop.travel(6) # Forward 6 seconds, so the request is not fresh anymore

      assert_includes 0..100, senec_provider.bat_fuel_charge
    end

    refute_predicate senec_provider, :bat_fuel_charge_increased?
  end

  def test_failed_request
    Senec::Local::Request.stub :new, ->(_args) { raise Senec::Local::Error } do
      assert_raises(Senec::Local::Error) { senec_provider.bat_fuel_charge }
    end
  end

  private

  def senec_provider
    SenecProvider.new(config: Config.from_env)
  end
end
