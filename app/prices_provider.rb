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
    return [] unless raw[0]

    raw[0].records.map { |r| r.values['_value'] }
  end

  private

  def time_range
    config.charger_price_time_range
  end

  def accepted_levels
    case config.charger_price_mode
    when :strict
      %w[VERY_CHEAP]
    when :relaxed
      %w[CHEAP VERY_CHEAP]
    end
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
      |> filter(fn: (r) => r["_field"] == "#{field}")
      |> yield()
    QUERY
  end

  def field
    'level'
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
