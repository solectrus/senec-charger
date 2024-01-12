require 'test_helper'

class PricesProviderTest < Minitest::Test
  def setup
    VCR.use_cassette('prices_setup') { fill_prices }
  end

  def teardown
    VCR.use_cassette('prices_delete') { delete_influx_data }
  end

  TIME = Time.parse('2023-12-01 10:30:00 +0100').freeze

  def test_best_prices_weight
    Timecop.travel(TIME) do
      VCR.use_cassette('prices_success') do
        # %w[CHEAP VERY_CHEAP VERY_CHEAP VERY_CHEAP]
        # 1 + 2 + 1 + 1 = 5
        assert_equal 5, prices_provider.best_prices_weight
      end
    end
  end

  def test_to_s
    # Travel to a time where we have any prices
    Timecop.travel(TIME) do
      VCR.use_cassette('prices_success') do
        assert_equal [
                       '12:00 0.153 (VERY_CHEAP)',
                       '13:00 0.176 (CHEAP)',
                       '14:00 0.15 (VERY_CHEAP)',
                       '15:00 0.149 (VERY_CHEAP)',
                     ].join(', '),
                     prices_provider.to_s
      end
    end
  end

  def test_to_s_empty
    # Travel to a time where we don't have any prices
    Timecop.travel('2023-05-02 12:10:00 +0200') do
      VCR.use_cassette('prices_blank') do
        assert_equal 'No prices found between 2023-05-02 12:00:00 +0200 and 2023-05-03 12:00:00 +0200',
                     prices_provider.to_s
      end
    end
  end

  def test_best_price_acceptable_strict
    config.stub :charger_price_mode, :strict do
      VCR.use_cassette('prices_success') do
        refute_predicate prices_provider, :best_price_acceptable?
      end
    end
  end

  def test_best_price_acceptable_moderate
    config.stub :charger_price_mode, :moderate do
      VCR.use_cassette('prices_success') do
        assert_predicate prices_provider, :best_price_acceptable?
      end
    end
  end

  def test_best_price_acceptable_relaxed
    config.stub :charger_price_mode, :relaxed do
      VCR.use_cassette('prices_success') do
        assert_predicate prices_provider, :best_price_acceptable?
      end
    end
  end

  def test_cheap_now_strict
    Timecop.travel(TIME) do
      config.stub :charger_price_mode, :strict do
        VCR.use_cassette('prices_success') do
          refute_predicate prices_provider, :cheap_now?
        end
      end
    end
  end

  def test_cheap_now_moderate_eleven_o_clock
    Timecop.travel('2023-12-01 11:00 +01') do
      config.stub :charger_price_mode, :moderate do
        VCR.use_cassette('prices_success') do
          refute_predicate prices_provider, :cheap_now?
        end
      end
    end
  end

  def test_cheap_now_moderate_twelve_o_clock
    Timecop.travel('2023-12-01 12:00 +01') do
      config.stub :charger_price_mode, :moderate do
        VCR.use_cassette('prices_success') do
          assert_predicate prices_provider, :cheap_now?
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

  ### Write fake prices to InfluxDB

  def fake_prices
    # Prices from some hours after TIME
    # Best 4-hour range is 12:00 - 16:00 (acceptable in moderate and relaxed mode)
    [
      { time: '2023-12-01 10:00 +01', amount: 0.157, level: 'CHEAP' },
      { time: '2023-12-01 11:00 +01', amount: 0.172, level: 'CHEAP' },
      #### Best 4-hour range starts here
      { time: '2023-12-01 12:00 +01', amount: 0.153, level: 'VERY_CHEAP' },
      { time: '2023-12-01 13:00 +01', amount: 0.176, level: 'CHEAP' },
      { time: '2023-12-01 14:00 +01', amount: 0.150, level: 'VERY_CHEAP' },
      { time: '2023-12-01 15:00 +01', amount: 0.149, level: 'VERY_CHEAP' },
      #### Best 4-hour range ends here
      { time: '2023-12-01 16:00 +01', amount: 0.191, level: 'EXPENSIVE' },
      { time: '2023-12-01 17:00 +01', amount: 0.199, level: 'VERY_EXPENSIVE' },
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

  def delete_api
    @delete_api ||= influx_client.create_delete_api
  end

  def influx_client
    @influx_client ||=
      InfluxDB2::Client.new(
        config.influx_url,
        config.influx_token,
        use_ssl: config.influx_schema == 'https',
        precision: InfluxDB2::WritePrecision::SECOND,
        bucket: config.influx_bucket,
        org: config.influx_org,
      )
  end

  def delete_influx_data(start: Time.at(0), stop: Time.at(2_147_483_647))
    delete_api.delete(start, stop)
  end
end
