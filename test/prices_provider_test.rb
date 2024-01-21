require 'test_helper'

class PricesProviderTest < Minitest::Test
  RELAXED = 80
  MODERATE = 70
  STRICT = 60

  def setup
    VCR.use_cassette('prices_setup') { fill_prices }
  end

  def teardown
    VCR.use_cassette('prices_delete') { delete_influx_data }
  end

  TIME = Time.parse('2023-12-01 10:30:00 +0100').freeze

  def test_prices_average
    Timecop.travel(TIME) do
      VCR.use_cassette('prices_success') do
        assert_in_delta 0.176, prices_provider.prices_average
      end
    end
  end

  def test_best_prices_average
    Timecop.travel(TIME) do
      VCR.use_cassette('prices_success') do
        assert_in_delta 0.138, prices_provider.best_prices_average
      end
    end
  end

  def test_to_s
    # Travel to a time where we have any prices
    Timecop.travel(TIME) do
      VCR.use_cassette('prices_success') do
        [/Checked prices of 15 hours between Friday, 10:00 - Saturday, 01:00, ⌀ 0.18/,
         /Best 4-hour range: Friday, 12:00 - Friday, 16:00, ⌀ 0.14/,
         %r{Ratio best/average: 78.5 %},].each do |line|
          assert_match line, prices_provider.to_s
        end
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

  def test_best_price_acceptable_relaxed
    config.stub :charger_price_max, RELAXED do
      VCR.use_cassette('prices_success') do
        assert_predicate prices_provider, :best_price_acceptable?
      end
    end
  end

  def test_best_price_acceptable_moderate
    config.stub :charger_price_max, MODERATE do
      VCR.use_cassette('prices_success') do
        refute_predicate prices_provider, :best_price_acceptable?
      end
    end
  end

  def test_best_price_acceptable_strict
    config.stub :charger_price_max, STRICT do
      VCR.use_cassette('prices_success') do
        refute_predicate prices_provider, :best_price_acceptable?
      end
    end
  end

  def test_cheap_now_strict
    Timecop.travel(TIME) do
      config.stub :charger_price_max, STRICT do
        VCR.use_cassette('prices_success') do
          refute_predicate prices_provider, :cheap_now?
        end
      end
    end
  end

  def test_cheap_now_moderate_eleven_o_clock
    Timecop.travel('2023-12-01 11:00 +01') do
      config.stub :charger_price_max, MODERATE do
        VCR.use_cassette('prices_success') do
          refute_predicate prices_provider, :cheap_now?
        end
      end
    end
  end

  def test_cheap_now_relaxed_twelve_o_clock
    Timecop.travel('2023-12-01 12:00 +01') do
      config.stub :charger_price_max, RELAXED do
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
    # Average price is 0.176
    # Best 4-hour range is 12:00 - 16:00 (average is 0.138)
    #
    # Ratio is 0.138 / 0.176 = 0.78
    # (acceptable for RELAXED, but not for MODERATE or STRICT)
    [
      { time: '2023-12-01 10:00 +01', amount: 0.167 },
      { time: '2023-12-01 11:00 +01', amount: 0.179 },
      #### Best 4-hour range starts here
      { time: '2023-12-01 12:00 +01', amount: 0.133 },
      { time: '2023-12-01 13:00 +01', amount: 0.138 },
      { time: '2023-12-01 14:00 +01', amount: 0.140 },
      { time: '2023-12-01 15:00 +01', amount: 0.142 },
      #### Best 4-hour range ends here
      { time: '2023-12-01 16:00 +01', amount: 0.191 },
      { time: '2023-12-01 17:00 +01', amount: 0.199 },
      { time: '2023-12-01 18:00 +01', amount: 0.198 },
      { time: '2023-12-01 19:00 +01', amount: 0.182 },
      { time: '2023-12-01 20:00 +01', amount: 0.191 },
      { time: '2023-12-01 21:00 +01', amount: 0.197 },
      { time: '2023-12-01 22:00 +01', amount: 0.196 },
      { time: '2023-12-01 23:00 +01', amount: 0.195 },
      { time: '2023-12-02 00:00 +01', amount: 0.193 },
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
