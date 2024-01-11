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

    assert_equal :allow_discharge, @battery_action.perform!
  end

  def test_perform_start_charge
    stub(@senec, :safe_charge_running?, false)
    stub(@senec, :bat_empty?, true)
    stub(@forecast, :sunshine_ahead?, false)
    stub(@prices, :cheap_grid_power?, true)
    stub(@senec, :start_charge!, nil)

    assert_equal :start_charge, @battery_action.perform!
  end

  def test_perform_still_charging
    stub(@senec, :safe_charge_running?, true)
    stub(@senec, :bat_fuel_charge, 10)
    stub(@senec, :bat_fuel_charge_increased?, true)

    assert_equal :still_charging, @battery_action.perform!
  end

  def test_perform_sunshine_ahead
    stub(@senec, :safe_charge_running?, false)
    stub(@senec, :bat_empty?, true)
    stub(@forecast, :sunshine_ahead?, true)

    assert_equal :sunshine_ahead, @battery_action.perform!
  end

  def test_perform_grid_power_expensive
    stub(@senec, :safe_charge_running?, false)
    stub(@senec, :bat_empty?, true)
    stub(@forecast, :sunshine_ahead?, false)
    stub(@prices, :cheap_grid_power?, false)

    assert_equal :grid_power_not_cheap, @battery_action.perform!
  end

  def test_perform_not_empty
    stub(@senec, :safe_charge_running?, false)
    stub(@senec, :bat_fuel_charge, 40)
    stub(@senec, :bat_empty?, false)
    stub(@senec, :bat_fuel_charge_increased?, false)

    assert_equal :not_empty, @battery_action.perform!
  end

  private

  def stub(object, method_name, return_value)
    object.define_singleton_method(method_name) { return_value }
  end
end
