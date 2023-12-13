require 'influxdb-client'

class PricesProvider
  def initialize(config:)
    @config = config
  end

  attr_reader :config

  ACCEPTED_LEVELS = %w[CHEAP VERY_CHEAP].freeze

  def cheap_grid_power?
    levels.count { |level| ACCEPTED_LEVELS.include?(level) } >= 4
  end

  def levels
    return [] unless raw[0]

    raw[0].records.map { |r| r.values['_value'] }
  end

  private

  def raw
    # Is the last request less than 30min ago?
    return @raw if @raw && @last_query_at && @last_query_at > Time.now - 1800

    @last_query_at = Time.now
    @raw = client.create_query_api.query(query:)
  end

  def query
    "from(bucket: \"#{config.influx_bucket}\")
      |> range(start: now(), stop: 4h)
      |> filter(fn: (r) => r[\"_measurement\"] == \"#{config.influx_measurement_prices}\")
      |> filter(fn: (r) => r[\"_field\"] == \"#{field}\")
      |> yield()
    "
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
