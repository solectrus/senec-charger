require 'net/http'
require 'influxdb-client'

require_relative 'senec_pull'

class Loop
  def self.start(config:, max_count: nil)
    new(config:, max_count:).start
  end

  def initialize(config:, max_count: nil)
    @config = config
    @max_count = max_count
  end

  attr_reader :config, :max_count

  def start
    self.count = 0

    loop do
      self.count += 1

      pull_from_senec
      pull_from_influx

      break if max_count && count >= max_count

      puts "  Sleeping for #{config.senec_interval} seconds ..."
      sleep config.senec_interval
    end
  end

  private

  attr_accessor :count

  def pull_from_senec
    print "##{count} Fetching data from SENEC ... "
    SenecPull.new(config:).next
    puts 'OK'
  end

  def pull_from_influx
    print '  Fetchting data from InfluxDB ... '
    # TODO
    puts 'OK'
  end
end
