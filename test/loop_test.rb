require 'test_helper'

class LoopTest < Minitest::Test
  def test_start_successful
    config = Config.from_env

    cassettes = [{ name: 'loop_success' }]

    out, err =
      capture_io do
        VCR.use_cassettes(cassettes) { Loop.start(config:, max_count: 2) }
      end

    assert_match(/#1/, out)
    assert_empty(err)
  end

  def test_output_start_charge
    out, err =
      capture_io do
        with_mocks(:start_charge) do
          Loop.start(config: Config.from_env, max_count: 1)
        end
      end

    assert_match(/Start charge!/, out)
    assert_match(/Battery charge level/, out)
    assert_match(/Forecast for the next 24 hours/, out)
    assert_match(/mocked prices/, out)
    assert_empty(err)
  end

  def test_output_sunshine_ahead
    out, err =
      capture_io do
        with_mocks(:sunshine_ahead) do
          Loop.start(config: Config.from_env, max_count: 1)
        end
      end

    assert_match(/Forecast for the next 24 hours/, out)
    assert_empty(err)
  end

  def test_output_allow_discharge
    out, err =
      capture_io do
        with_mocks(:allow_discharge) do
          Loop.start(config: Config.from_env, max_count: 1)
        end
      end

    assert_match(/Battery charge level/, out)
    assert_empty(err)
  end

  def test_output_no_cheap_grid_power_ahead
    out, err =
      capture_io do
        with_mocks(:no_cheap_grid_power_ahead) do
          Loop.start(config: Config.from_env, max_count: 1)
        end
      end

    assert_match(/Grid power not cheap/, out)
    assert_empty(err)
  end

  private

  def with_mocks(result, &)
    battery_action = Minitest::Mock.new
    battery_action.expect(:perform!, result)

    senec = Minitest::Mock.new
    senec.expect(:bat_fuel_charge, 50)

    forecast = Minitest::Mock.new
    forecast.expect(:time_range, 24)
    forecast.expect(:total_in_kwh, 5)

    prices = Minitest::Mock.new
    prices.expect(:time_range, 4)
    prices.expect(:to_s, 'mocked prices')

    BatteryAction.stub(:new, battery_action) do
      PricesProvider.stub(:new, prices) do
        ForecastProvider.stub(:new, forecast) do
          SenecProvider.stub(:new, senec, &)
        end
      end
    end
  end
end
