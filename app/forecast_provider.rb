require 'influxdb-client'

class ForecastProvider
  def initialize(config:)
    @config = config
  end

  attr_reader :config

  def sunshine_ahead?
    total_in_kwh > config.charger_forecast_threshold
  end

  def total_in_kwh
    return 0.0 unless raw[0]

    raw[0].records[0].value.round
  end

  def time_range
    24
  end

  private

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
      |> filter(fn: (r) => r["_measurement"] == "#{config.influx_measurement_forecast}")
      |> filter(fn: (r) => r["_field"] == "#{field}")
      |> aggregateWindow(every: 1h, fn: mean, createEmpty: false)
      |> map(fn: (r) => ({ r with _value: r._value / 1000.0 }))
      |> sum()
    QUERY
  end

  def range_start
    Time.now
  end

  def range_stop
    range_start + (time_range * 3600)
  end

  def field
    'watt'
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
