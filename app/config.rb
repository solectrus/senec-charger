Config =
  Struct.new(
    :senec_host,
    :senec_schema,
    :charger_interval,
    :charger_price_mode,
    :charger_price_time_range,
    :charger_forecast_threshold,
    :charger_dry_run,
    :influx_schema,
    :influx_host,
    :influx_port,
    :influx_token,
    :influx_org,
    :influx_bucket,
    :influx_measurement_prices,
    :influx_measurement_forecast,
    keyword_init: true,
  ) do
    def initialize(*options)
      super

      validate_url!(senec_url)
      validate_url!(influx_url)
      validate_interval!(charger_interval)
      validate_price_mode!(charger_price_mode)
      validate_price_time_range!(charger_price_time_range)
      validate_forecast_threshold!(charger_forecast_threshold)
    end

    def influx_url
      "#{influx_schema}://#{influx_host}:#{influx_port}"
    end

    def senec_url
      "#{senec_schema}://#{senec_host}"
    end

    def senec_connection
      @senec_connection ||=
        Senec::Local::Connection.new(host: senec_host, schema: senec_schema)
    end

    private

    def validate_interval!(interval)
      (interval.is_a?(Integer) && interval.positive?) ||
        throw("Interval is invalid: #{interval}")
    end

    def validate_price_mode!(price_mode)
      %i[strict moderate relaxed].include?(price_mode) ||
        throw("Price mode is invalid: #{price_mode}")
    end

    def validate_price_time_range!(price_time_range)
      (price_time_range.is_a?(Integer) && price_time_range.positive?) ||
        throw("Time range is invalid: #{price_time_range}")
    end

    def validate_forecast_threshold!(forecast_threshold)
      (forecast_threshold.is_a?(Integer) && forecast_threshold.positive?) ||
        throw("Forecast threshold is invalid: #{forecast_threshold}")
    end

    def validate_url!(url)
      uri = URI.parse(url)

      (uri.is_a?(URI::HTTP) && !uri.host.nil?) ||
        throw("URL is invalid: #{url}")
    end

    def self.from_env(options = {})
      new(
        {
          senec_host: ENV.fetch('SENEC_HOST'),
          senec_schema: ENV.fetch('SENEC_SCHEMA', 'https'),
          charger_interval: ENV.fetch('CHARGER_INTERVAL', '3600').to_i,
          charger_price_mode:
            ENV.fetch('CHARGER_PRICE_MODE', 'moderate').to_sym,
          charger_price_time_range:
            ENV.fetch('CHARGER_PRICE_TIME_RANGE', '4').to_i,
          charger_forecast_threshold:
            ENV.fetch('CHARGER_FORECAST_THRESHOLD', '20').to_i,
          charger_dry_run: ENV.fetch('CHARGER_DRY_RUN', 'false') == 'true',
          influx_host: ENV.fetch('INFLUX_HOST'),
          influx_schema: ENV.fetch('INFLUX_SCHEMA', 'http'),
          influx_port: ENV.fetch('INFLUX_PORT', '8086'),
          influx_token: ENV.fetch('INFLUX_TOKEN'),
          influx_org: ENV.fetch('INFLUX_ORG'),
          influx_bucket: ENV.fetch('INFLUX_BUCKET'),
          influx_measurement_prices:
            ENV.fetch('INFLUX_MEASUREMENT_PRICES', 'Prices'),
          influx_measurement_forecast:
            ENV.fetch('INFLUX_MEASUREMENT_FORECAST', 'Forecast'),
        }.merge(options),
      )
    end
  end
