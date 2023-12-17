require 'test_helper'

class ForecastProviderTest < Minitest::Test
  def setup
    VCR.use_cassette('forecast_setup') { fill_forecast }
  end

  TIME = Time.parse('2023-12-01 10:30:00 +0100').freeze

  def test_success_request
    Timecop.travel(TIME) do
      VCR.use_cassette('forecast_success') do
        assert_predicate forecast_provider, :sunshine_ahead?
      end
    end
  end

  private

  def forecast_provider
    @forecast_provider ||= ForecastProvider.new(config:)
  end

  def config
    @config ||= Config.from_env
  end

  def fake_forecast
    # Forecast from 10:00 to 13:00 for TIME
    [
      { time: '2023-12-01 10:00:00 +0100', watt: 5500 },
      { time: '2023-12-01 11:00:00 +0100', watt: 9600 },
      { time: '2023-12-01 12:00:00 +0100', watt: 3700 },
      { time: '2023-12-01 13:00:00 +0100', watt: 8800 },
    ]
  end

  def forecast_points
    fake_forecast.map do |forecast|
      InfluxDB2::Point.new(
        name: config.influx_measurement_forecast,
        time: Time.parse(forecast[:time]).to_i,
        fields: {
          watt: forecast[:watt],
        },
      )
    end
  end

  def fill_forecast
    write_api.write(
      data: forecast_points,
      bucket: config.influx_bucket,
      org: config.influx_org,
    )
  end

  def write_api
    @write_api ||= influx_client.create_write_api
  end

  def influx_client
    @influx_client ||=
      InfluxDB2::Client.new(
        config.influx_url,
        config.influx_token,
        use_ssl: config.influx_schema == 'https',
        precision: InfluxDB2::WritePrecision::SECOND,
      )
  end
end
