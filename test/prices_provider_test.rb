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
    VCR.use_cassette('prices_success') do
      output = prices_provider.to_s

      # Verify the structure of the new multi-line log
      # Line 1: Basic info
      assert_match(/Checked prices \d{2}:\d{2}-\d{2}:\d{2}/, output)
      assert_match(/Ref Ø \d+\.\d+/, output)

      # Line 2: Best slot
      assert_match(/Best slot: \d{2}:\d{2} - \d{2}:\d{2} @ \d+\.\d+/, output)

      # Line 3: Decision logic
      assert_match(/Decision:  \d+\.\d+% of Ref/, output)
      assert_match(/-> (CHEAP|EXPENSIVE)/, output)
    end
  end

  def test_to_s_empty
    # Travel to a time where we don't have any prices
    Timecop.travel('2023-05-02 12:10:00 +0200') do
      VCR.use_cassette('prices_blank') do
        # UPDATE: Expect the new simple message
        assert_equal 'No prices available', prices_provider.to_s
      end
    end
  end

  def test_to_s_with_filter
    # Verify that the log explicitly mentions the filter when active
    config.stub :charger_price_comparison_hour_start, 6 do
      config.stub :charger_price_comparison_hour_end, 20 do
        VCR.use_cassette('prices_success') do
          output = prices_provider.to_s

          assert_match(/\(filtered 6:00-20:00\)/, output)
        end
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

  def test_best_price_acceptable_moderate_with_comparison_range
    # In the fake_prices data:
    # - Best 4h average: 0.138
    # - Global 24h average: 0.176
    # - MODERATE threshold (70%): 0.176 * 0.7 = 0.123
    # 0.138 is NOT <= 0.123, so this normally fails (refute_predicate).

    # We configure the comparison range to 17:00 - 18:00.
    # - Price at 17:00-18:00: 0.199
    # - New Reference Average: 0.199
    # - New Threshold (70%): 0.199 * 0.7 = 0.1393
    # 0.138 IS <= 0.1393, so this should now PASS.

    config.stub :charger_price_max, MODERATE do
      config.stub :charger_price_comparison_hour_start, 17 do
        config.stub :charger_price_comparison_hour_end, 18 do
          VCR.use_cassette('prices_success') do
            assert_predicate prices_provider, :best_price_acceptable?
          end
        end
      end
    end

    # This prevents local .env settings from breaking standard tests
    @config.charger_price_comparison_hour_start = nil
    @config.charger_price_comparison_hour_end = nil
  end

  private

  def prices_provider
    @prices_provider ||= PricesProvider.new(config:)
  end

  def config
    @config ||= Config.from_env
  end

  ### Write fake prices to InfluxDB

  def fake_prices # rubocop:disable Metrics/AbcSize
    # Prices with 15-minute intervals after TIME
    # Average price is 0.176
    # Best 4-hour range is 12:00 - 16:00 (average is 0.138)
    #
    # Ratio is 0.138 / 0.176 = 0.78
    # (acceptable for RELAXED, but not for MODERATE or STRICT)
    prices = []

    # 10:00 - 11:00 (average: 0.167)
    4.times { |i| prices << { time: "2023-12-01 10:#{i * 15}:00 +01", amount: 0.167 } }

    # 11:00 - 12:00 (average: 0.179)
    4.times { |i| prices << { time: "2023-12-01 11:#{i * 15}:00 +01", amount: 0.179 } }

    #### Best 4-hour range starts here
    # 12:00 - 13:00 (average: 0.133)
    4.times { |i| prices << { time: "2023-12-01 12:#{i * 15}:00 +01", amount: 0.133 } }

    # 13:00 - 14:00 (average: 0.138)
    4.times { |i| prices << { time: "2023-12-01 13:#{i * 15}:00 +01", amount: 0.138 } }

    # 14:00 - 15:00 (average: 0.140)
    4.times { |i| prices << { time: "2023-12-01 14:#{i * 15}:00 +01", amount: 0.140 } }

    # 15:00 - 16:00 (average: 0.142)
    4.times { |i| prices << { time: "2023-12-01 15:#{i * 15}:00 +01", amount: 0.142 } }
    #### Best 4-hour range ends here

    # 16:00 - 17:00 (average: 0.191)
    4.times { |i| prices << { time: "2023-12-01 16:#{i * 15}:00 +01", amount: 0.191 } }

    # 17:00 - 18:00 (average: 0.199)
    4.times { |i| prices << { time: "2023-12-01 17:#{i * 15}:00 +01", amount: 0.199 } }

    # 18:00 - 19:00 (average: 0.198)
    4.times { |i| prices << { time: "2023-12-01 18:#{i * 15}:00 +01", amount: 0.198 } }

    # 19:00 - 20:00 (average: 0.182)
    4.times { |i| prices << { time: "2023-12-01 19:#{i * 15}:00 +01", amount: 0.182 } }

    # 20:00 - 21:00 (average: 0.191)
    4.times { |i| prices << { time: "2023-12-01 20:#{i * 15}:00 +01", amount: 0.191 } }

    # 21:00 - 22:00 (average: 0.197)
    4.times { |i| prices << { time: "2023-12-01 21:#{i * 15}:00 +01", amount: 0.197 } }

    # 22:00 - 23:00 (average: 0.196)
    4.times { |i| prices << { time: "2023-12-01 22:#{i * 15}:00 +01", amount: 0.196 } }

    # 23:00 - 00:00 (average: 0.195)
    4.times { |i| prices << { time: "2023-12-01 23:#{i * 15}:00 +01", amount: 0.195 } }

    # 00:00 - 01:00 (average: 0.193)
    4.times { |i| prices << { time: "2023-12-02 00:#{i * 15}:00 +01", amount: 0.193 } }

    prices
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
