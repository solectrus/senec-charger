require 'test_helper'

class ConfigTest < Minitest::Test
  VALID_OPTIONS = {
    senec_host: '192.168.1.2',
    senec_interval: 900,
    senec_schema: 'http',
    influx_host: 'influx.example.com',
    influx_schema: 'https',
    influx_port: '443',
    influx_token: 'this.is.just.an.example',
    influx_org: 'my-org',
    influx_bucket: 'my-bucket',
    influx_measurement_prices: 'my-measurement-prices',
    influx_measurement_forecast: 'my-measurement-forecast',
  }.freeze

  def test_valid_options
    Config.new(VALID_OPTIONS)
  end

  def test_invalid_options
    assert_raises(Exception) { Config.new({}) }

    error =
      assert_raises(Exception) do
        Config.new(VALID_OPTIONS.merge(senec_interval: 0))
      end

    assert_match(/Interval is invalid/, error.message)

    error =
      assert_raises(Exception) do
        Config.new(VALID_OPTIONS.merge(influx_schema: 'foo'))
      end

    assert_match(/URL is invalid/, error.message)
  end

  def test_senec_methods
    config = Config.new(VALID_OPTIONS)

    assert_equal 900, config.senec_interval
  end

  def test_influx_methods
    config = Config.new(VALID_OPTIONS)

    assert_equal 'influx.example.com', config.influx_host
    assert_equal 'https', config.influx_schema
    assert_equal '443', config.influx_port
    assert_equal 'this.is.just.an.example', config.influx_token
    assert_equal 'my-org', config.influx_org
    assert_equal 'my-bucket', config.influx_bucket
    assert_equal 'my-measurement-prices', config.influx_measurement_prices
    assert_equal 'my-measurement-forecast', config.influx_measurement_forecast
  end

  def test_from_env
    config = Config.from_env

    assert_equal 'localhost', config.influx_host
    assert_equal 'http', config.influx_schema
    assert_equal '8086', config.influx_port
    assert_equal 'my-token', config.influx_token
    assert_equal 'my-org', config.influx_org
    assert_equal 'my-bucket', config.influx_bucket
    assert_equal 'my-measurement-prices', config.influx_measurement_prices
    assert_equal 'my-measurement-forecast', config.influx_measurement_forecast
  end
end
