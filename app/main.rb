#!/usr/bin/env ruby

require 'dotenv/load'
require_relative 'loop'
require_relative 'config'

# Flush output immediately
$stdout.sync = true

puts 'SENEC charger for SOLECTRUS, ' \
       "Version #{ENV.fetch('VERSION', '<unknown>')}, " \
       "built at #{ENV.fetch('BUILDTIME', '<unknown>')}"
puts 'https://github.com/solectrus/senec-charger'
puts 'Copyright (c) 2023-2024 Georg Ledermann, released under the MIT License'
puts "\n"

config = Config.from_env

puts "Using Ruby #{RUBY_VERSION} on platform #{RUBY_PLATFORM}"
puts "Connecting to SENEC at #{config.senec_url}"
puts "Connecting to InfluxDB at #{config.influx_url}, " \
       "bucket #{config.influx_bucket}, " \
       "measurements #{config.influx_measurement_prices} and #{config.influx_measurement_forecast}"
puts '+++ DRY RUN MODE +++' if config.charger_dry_run
puts "\n"

Loop.start(config:)
