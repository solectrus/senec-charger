Config =
  Struct.new(
    :senec_host,
    :senec_schema,
    :charger_interval,
    :charger_price_max,
    :charger_price_time_range,
    :charger_forecast_threshold,
    :charger_price_comparison_hour_start,
    :charger_price_comparison_hour_end,
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
      validate_price_max!(charger_price_max)
      validate_price_time_range!(charger_price_time_range)
      validate_forecast_threshold!(charger_forecast_threshold)
      validate_price_comparison_hours!(charger_price_comparison_hour_start, charger_price_comparison_hour_end)
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

    def validate_price_max!(price_max)
      (price_max.positive? && price_max < 100) ||
        throw("Price max is invalid: #{price_max}")
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

    def validate_price_comparison_hours!(start_hour, end_hour)
      # Valid if both are nil (feature disabled)
      return if start_hour.nil? && end_hour.nil?

      # Invalid if only one is set
      if start_hour.nil? || end_hour.nil?
        raise ArgumentError, 'Both start and end hour must be set for price comparison'
      end

      # Invalid if out of bounds (0-23)
      unless (0..23).cover?(start_hour) && (0..23).cover?(end_hour)
        raise ArgumentError, 'Price comparison hours must be between 0 and 23'
      end

      # Invalid if start is not before end
      return if start_hour < end_hour

      raise ArgumentError, 'Price comparison start hour must be before end hour'
    end

    def self.from_env(options = {})
      new(
        {
          senec_host: ENV.fetch('SENEC_HOST'),
          senec_schema: ENV.fetch('SENEC_SCHEMA', 'https'),
          charger_interval: ENV.fetch('CHARGER_INTERVAL', '3600').to_i,
          charger_price_max:
            ENV.fetch('CHARGER_PRICE_MAX', '70').to_i,
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
          charger_price_comparison_hour_start: ENV['CHARGER_PRICE_COMPARISON_HOUR_START']&.to_i,
          charger_price_comparison_hour_end: ENV['CHARGER_PRICE_COMPARISON_HOUR_END']&.to_i,
        }.merge(options),
      )
    end
  end
