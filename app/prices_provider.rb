require 'influxdb-client'

class PricesProvider
  def initialize(config:)
    @config = config
  end

  attr_reader :config

  def cheap_now?
    best_price_acceptable? && best_prices_now?
  end

  def cheap_ahead?
    best_price_acceptable? && !best_prices_now?
  end

  def best_price_acceptable?
    # We need a valid best price average
    return false unless best_prices_average

    # Determine the reference price to compare against.
    # Use the comparison average (filtered) if available, otherwise the full average.
    # If a range is configured but no prices exist for it (ref_price is nil),
    # we return false to be safe.
    # 1. Try to get the average of the configured time window (comparison_average).
    # 2. If not configured (or empty), fall back to the full 24h average (prices_average).
    ref_price = comparison_average || prices_average
    return false unless ref_price

    best_prices_average <= ref_price * config.charger_price_max / 100
  end

  def best_prices_now?
    best_prices.first&.time&.between?(Time.now - 900, Time.now)
  end

  def best_prices_average
    average(best_prices)
  end

  def prices_average
    average(prices)
  end

  def to_s # rubocop:disable Metrics/AbcSize
    if prices.any?
      <<~RESULT
        Checked prices between #{prices.first.time.strftime('%A, %H:%M')} - #{end_time(prices).strftime('%A, %H:%M')}, ⌀ #{prices_average.round(2)}
        Best #{config.charger_price_time_range}-hour range: #{best_prices.first.time.strftime('%A, %H:%M')} - #{end_time(best_prices).strftime('%A, %H:%M')}, ⌀ #{best_prices_average.round(2)}
        Ratio best/average: #{(best_prices_average * 100 / prices_average).round(1)} %
      RESULT
    else
      "No prices found between #{range_start} and #{range_stop}"
    end
  end

  def end_time(price_list)
    return Time.now if price_list.empty?

    price_list.last.time + detect_interval_size(price_list)
  end

  Price = Struct.new(:time, :amount)

  private

  # Returns the average of the specific time window (if configured)
  # Returns nil if the filtered list is empty
  def comparison_average
    average(comparison_prices)
  end

  def comparison_prices
    # Because of Config validation, we know if one is set, both are set and valid.
    return prices unless config.charger_price_comparison_hour_start && config.charger_price_comparison_hour_end

    # Filter prices to only include those within the configured hour range
    prices.select do |price|
      hour = price.time.hour
      hour.between?(config.charger_price_comparison_hour_start, config.charger_price_comparison_hour_end)
    end
  end

  def average(cons)
    return if cons.empty?

    cons.sum(&:amount) / cons.size
  end

  # Detect interval size from price data (returns seconds)
  # Defaults to 900 seconds (15 minutes) if not enough data
  def detect_interval_size(price_list)
    price_list.size >= 2 ? (price_list[1].time - price_list[0].time) : 900
  end

  # Find the time slot with cheapest price
  def best_prices
    return [] if prices.empty?

    time_range_seconds = config.charger_price_time_range * 3600

    # Build sliding windows: for each price point, collect all prices
    # within the configured time range starting from that point
    windows = prices.map { |start_price| build_window(start_price, time_range_seconds) }

    # Only consider complete windows that span the full configured time range
    complete_windows = windows.select { |window| complete_window?(window, time_range_seconds) }

    # Return the window with the lowest average price
    complete_windows.min_by { |window| average(window) } || []
  end

  def build_window(start_price, time_range_seconds)
    end_time = start_price.time + time_range_seconds
    prices.select { |p| p.time >= start_price.time && p.time < end_time }
  end

  def complete_window?(window, time_range_seconds)
    return false if window.empty?

    actual_duration = window.last.time - window.first.time
    # Allow tolerance of one interval
    actual_duration >= time_range_seconds - detect_interval_size(window)
  end

  # Return prices as an array of hashes (with keys: time, amount)
  def prices
    return [] unless amount_table

    amount_table
      .records
      .map do |amount_record|
        Price.new(
          time: Time.parse(amount_record.time).localtime,
          amount: amount_record.value,
        )
      end
  end

  # Get the table with values for the "amount" field
  def amount_table
    raw.find { |table| table.records.first.field == 'amount' }
  end

  def raw
    # Cache for 1 minute
    return @raw if @raw && @last_query_at && @last_query_at > Time.now - 60

    @last_query_at = Time.now
    @raw = client.create_query_api.query(query:)
  end

  def query
    <<~QUERY
      from(bucket: "#{config.influx_bucket}")
      |> range(start: #{range_start.to_i}, stop: #{range_stop.to_i})
      |> filter(fn: (r) => r["_measurement"] == "#{config.influx_measurement_prices}")
      |> filter(fn: (r) => r["_field"] == "amount")
      |> yield()
    QUERY
  end

  def range_start
    now = Time.now
    # Round down to the nearest 15-minute interval
    minutes = (now.min / 15) * 15
    Time.new(now.year, now.month, now.day, now.hour, minutes)
  end

  def range_stop
    # 24 hours from range_start
    range_start + (24 * 3_600)
  end

  def client
    InfluxDB2::Client.new(
      config.influx_url,
      config.influx_token,
      bucket: config.influx_bucket,
      org: config.influx_org,
      use_ssl: config.influx_schema == 'https',
      read_timeout: 30,
    )
  end
end
