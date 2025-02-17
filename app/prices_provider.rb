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
    return false unless best_prices_average && prices_average

    best_prices_average <= prices_average * config.charger_price_max / 100
  end

  def best_prices_now?
    best_prices.first&.time&.between?(Time.now - 3600, Time.now)
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
        Checked prices of #{prices.size} hours between #{prices.first.time.strftime('%A, %H:%M')} - #{(prices.last.time + 3600).strftime('%A, %H:%M')}, ⌀ #{prices_average.round(2)}
        Best #{config.charger_price_time_range}-hour range: #{best_prices.first.time.strftime('%A, %H:%M')} - #{(best_prices.last.time + 3600).strftime('%A, %H:%M')}, ⌀ #{best_prices_average.round(2)}
        Ratio best/average: #{(best_prices_average * 100 / prices_average).round(1)} %
      RESULT
    else
      "No prices found between #{range_start} and #{range_stop}"
    end
  end

  Price = Struct.new(:time, :amount)

  private

  def average(cons)
    return if cons.empty?

    cons.sum(&:amount) / cons.size
  end

  # Find the time slot with cheapest price
  def best_prices
    prices
      .each_cons(config.charger_price_time_range)
      .min_by { |cons| average(cons) } || []
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
