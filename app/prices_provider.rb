require 'influxdb-client'

class PricesProvider
  def initialize(config:)
    @config = config
  end

  attr_reader :config

  def cheap_grid_power?
    levels.count { |level| accepted_levels.include?(level) } >= time_range
  end

  def levels
    prices.map { |price| price[:level] }
  end

  def to_s
    if prices.any?
      prices
        .map { |price| "#{price[:time]} #{price[:amount]} (#{price[:level]})" }
        .join(', ')
    else
      "No prices found between #{range_start} and #{range_stop}"
    end
  end

  def time_range
    config.charger_price_time_range
  end

  private

  def accepted_levels
    case config.charger_price_mode
    when :strict
      %w[VERY_CHEAP]
    when :relaxed
      %w[CHEAP VERY_CHEAP]
    end
  end

  # Return prices as an array of hashes (with keys: time, amount, level)
  def prices
    return [] unless amount_table && level_table

    amount_table
      .records
      .zip(level_table.records)
      .map do |amount, level|
        {
          time: Time.parse(amount.time).localtime.strftime('%H:%M'),
          amount: amount.value,
          level: level.value,
        }
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
    # Is the last request less than 30min ago?
    return @raw if @raw && @last_query_at && @last_query_at > Time.now - 1800

    @last_query_at = Time.now
    @raw = client.create_query_api.query(query:)
  end

  def query
    <<~QUERY
      from(bucket: "#{config.influx_bucket}")
      |> range(start: now(), stop: #{time_range}h)
      |> filter(fn: (r) => r["_measurement"] == "#{config.influx_measurement_prices}")
      |> filter(fn: (r) => r["_field"] == "level" or r["_field"] == "amount")
      |> yield()
    QUERY
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
