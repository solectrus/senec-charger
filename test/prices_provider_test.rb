require 'test_helper'

class PricesProviderTest < Minitest::Test
  def setup
    VCR.use_cassette('prices_setup') { fill_prices }
  end

  TIME = Time.parse('2023-12-01 10:30:00 +0100').freeze

  def test_levels
    Timecop.travel(TIME) do
      VCR.use_cassette('prices_success') do
        assert_equal %w[CHEAP VERY_CHEAP VERY_CHEAP VERY_CHEAP],
                     prices_provider.levels
      end
    end
  end

  def test_to_s
    # Travel to a time where we have any prices
    Timecop.travel(TIME) do
      VCR.use_cassette('prices_success') do
        assert_equal [
                       '10:00 0.157 (CHEAP)',
                       '11:00 0.172 (VERY_CHEAP)',
                       '12:00 0.153 (VERY_CHEAP)',
                       '13:00 0.176 (VERY_CHEAP)',
                     ].join(', '),
                     prices_provider.to_s
      end
    end
  end

  def test_to_s_empty
    # Travel to a time where we don't have any prices
    Timecop.travel('2023-05-02 12:10:00 +0200') do
      VCR.use_cassette('prices_blank') do
        assert_equal 'No prices found between 2023-05-02 12:00:00 +0200 and 2023-05-02 16:00:00 +0200',
                     prices_provider.to_s
      end
    end
  end

  def test_cheapest_grid_power_strict
    Timecop.travel(TIME) do
      config.stub :charger_price_mode, :strict do
        VCR.use_cassette('prices_success') do
          refute_predicate prices_provider, :cheap_grid_power?
        end
      end
    end
  end

  def test_cheapest_grid_power_relaxed
    Timecop.travel(TIME) do
      config.stub :charger_price_mode, :relaxed do
        VCR.use_cassette('prices_success') do
          assert_predicate prices_provider, :cheap_grid_power?
        end
      end
    end
  end

  private

  def prices_provider
    @prices_provider ||= PricesProvider.new(config:)
  end

  def config
    @config ||= Config.from_env
  end

  def fake_prices
    # Prices from 10:00 to 13:00 for TIME
    [
      { time: '2023-12-01 10:00:00 +0100', amount: 0.157, level: 'CHEAP' },
      { time: '2023-12-01 11:00:00 +0100', amount: 0.172, level: 'VERY_CHEAP' },
      { time: '2023-12-01 12:00:00 +0100', amount: 0.153, level: 'VERY_CHEAP' },
      { time: '2023-12-01 13:00:00 +0100', amount: 0.176, level: 'VERY_CHEAP' },
    ]
  end

  def price_points
    fake_prices.map do |price|
      InfluxDB2::Point.new(
        name: config.influx_measurement_prices,
        time: Time.parse(price[:time]).to_i,
        fields: {
          amount: price[:amount],
          level: price[:level],
        },
      )
    end
  end

  def fill_prices
    write_api.write(
      data: price_points,
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
