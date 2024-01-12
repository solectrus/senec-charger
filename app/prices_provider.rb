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
    best_prices_weight <= max_acceptable_weight
  end

  def best_prices_now?
    best_prices.first&.time&.between?(Time.now - 3600, Time.now)
  end

  def best_prices_weight
    weight(best_prices)
  end

  def to_s
    if prices.any?
      best_prices
        .map do |price|
          "#{price.time.strftime('%H:%M')} #{price.amount} (#{price.level})"
        end
        .join(', ')
    else
      "No prices found between #{range_start} and #{range_stop}"
    end
  end

  private

  LEVEL_WEIGHTS = {
    'VERY_CHEAP' => 1,
    'CHEAP' => 2,
    'NORMAL' => 3,
    'EXPENSIVE' => 4,
    'VERY_EXPENSIVE' => 5,
  }.freeze

  def max_acceptable_weight
    factor =
      { strict: 1.0, moderate: 1.5, relaxed: 2.0 }[config.charger_price_mode]

    (factor * config.charger_price_time_range).round
  end

  def weight(cons)
    cons.sum do |price|
      LEVEL_WEIGHTS[price.level] || throw("Unknown level: #{price.level}")
    end
  end

  # Find the timeslot with cheapest price level
  def best_prices
    prices
      .each_cons(config.charger_price_time_range)
      .min_by { |cons| weight(cons) } || []
  end

  Price = Struct.new(:time, :amount, :level)

  # Return prices as an array of hashes (with keys: time, amount, level)
  def prices
    return [] unless amount_table && level_table

    amount_table
      .records
      .zip(level_table.records)
      .map do |amount_record, level_record|
        Price.new(
          time: Time.parse(amount_record.time).localtime,
          amount: amount_record.value,
          level: level_record.value,
        )
      end
  end

  # Get the table with values for the "amount" field
  def amount_table
    raw.find { |table| table.records.first.field == 'amount' }
  end

  # Get the table with values for the "level" field
  def level_table
    raw.find { |table| table.records.first.field == 'level' }
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
      |> filter(fn: (r) => r["_field"] == "level" or r["_field"] == "amount")
      |> yield()
    QUERY
  end

  def range_start
    now = Time.now
    Time.new(now.year, now.month, now.day, now.hour)
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
