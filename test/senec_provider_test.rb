require 'test_helper'

class SenecProviderTest < Minitest::Test
  def test_success_request
    VCR.use_cassette('senec_success') do
      assert_includes 0..100, senec_provider.bat_fuel_charge
      assert_includes [false, true], senec_provider.safe_charge_running?
      assert_predicate senec_provider, :bat_fuel_charge_increased?
    end
  end

  def test_stale_request
    # First reuqest
    with_stubbed_request(bat_fuel_charge: 12.1) do
      assert_in_delta 12.1, senec_provider.bat_fuel_charge
      assert_predicate senec_provider, :bat_fuel_charge_increased?
    end

    # Wait 1 second, so the request is still fresh, no new request is made
    Timecop.travel(1)

    assert_in_delta 12.1, senec_provider.bat_fuel_charge

    # Forward 60 seconds, so the request is not fresh anymore, a new request is made
    Timecop.travel(60)

    with_stubbed_request(bat_fuel_charge: 15.0) do
      assert_in_delta 15.0, senec_provider.bat_fuel_charge
      assert_predicate senec_provider, :bat_fuel_charge_increased?
    end
  end

  def test_failed_request
    Senec::Local::Request.stub :new, ->(_args) { raise Senec::Local::Error } do
      assert_raises(Senec::Local::Error) { senec_provider.bat_fuel_charge }
    end
  end

  def test_start_charge!
    VCR.use_cassette('senec_start_charge') { senec_provider.start_charge! }
  end

  def test_allow_discharge!
    VCR.use_cassette('senec_allow_discharge') do
      senec_provider.allow_discharge!
    end
  end

  private

  def senec_provider
    @senec_provider ||= SenecProvider.new(config:)
  end

  def config
    @config ||= Config.from_env
  end

  def with_stubbed_request(bat_fuel_charge:, safe_charge_running: 0, &)
    VCR.turned_off do
      WebMock.stub_request(
        :post,
        "#{config.senec_schema}://#{config.senec_host}/lala.cgi",
      ).to_return(
        body: {
          'ENERGY' => {
            'GUI_BAT_DATA_FUEL_CHARGE' => float_to_string(bat_fuel_charge),
            'SAFE_CHARGE_RUNNING' => int_to_string(safe_charge_running),
          },
        }.to_json,
      )

      yield

      WebMock.reset!
    end
  end

  def float_to_string(value)
    "fl_#{[value].pack('g').unpack1('H*')}"
  end

  def int_to_string(value)
    "u8_#{[value].pack('C').unpack1('H*')}"
  end
end
