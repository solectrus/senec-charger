require 'test_helper'

class BatteryActionTest < Minitest::Test
  def setup
    config = nil

    @senec = SenecProvider.new(config:)
    @prices = PricesProvider.new(config:)
    @forecast = ForecastProvider.new(config:)

    @battery_action =
      BatteryAction.new(senec: @senec, prices: @prices, forecast: @forecast)
  end

  def test_perform_discharge
    stub(@senec, :safe_charge_running?, true)
    stub(@senec, :bat_fuel_charge_increased?, false)
    stub(@senec, :allow_discharge!, nil)

    perform_and_expect('Allow discharge!')
  end

  def test_perform_start_charge
    stub(@senec, :safe_charge_running?, false)
    stub(@senec, :bat_empty?, true)
    stub(@forecast, :sunshine_ahead?, false)
    stub(@prices, :cheap_grid_power?, true)
    stub(@senec, :start_charge!, nil)

    perform_and_expect('Start charge!')
  end

  def test_perform_still_charging
    stub(@senec, :safe_charge_running?, true)
    stub(@senec, :bat_fuel_charge, 10)
    stub(@senec, :bat_fuel_charge_increased?, true)

    perform_and_expect('Still charging')
  end

  def test_perform_sunshine_ahead
    stub(@senec, :safe_charge_running?, false)
    stub(@senec, :bat_empty?, true)
    stub(@forecast, :sunshine_ahead?, true)

    perform_and_expect('Sunshine ahead')
  end

  def test_perform_grid_power_expensive
    stub(@senec, :safe_charge_running?, false)
    stub(@senec, :bat_empty?, true)
    stub(@forecast, :sunshine_ahead?, false)
    stub(@prices, :cheap_grid_power?, false)

    perform_and_expect('Grid power expensive')
  end

  private

  def stub(object, method_name, return_value)
    object.define_singleton_method(method_name) { return_value }
  end

  def perform_and_expect(message)
    out, err = capture_io { @battery_action.perform! }

    assert_match(message, out)
    assert_empty(err)
  end
end
