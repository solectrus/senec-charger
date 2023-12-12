require 'test_helper'
require 'forecast_provider'
require 'config'

class ForecastProviderTest < Minitest::Test
  def test_success_request
    VCR.use_cassette('forecast_success') do
      refute_predicate forecast_provider, :sunshine_ahead?
    end
  end

  private

  def forecast_provider
    @forecast_provider ||= ForecastProvider.new(config: Config.from_env)
  end
end
