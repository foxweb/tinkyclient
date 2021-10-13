require 'faraday'
require 'faraday_middleware'
require 'faraday_middleware/parse_oj'

module Tinky
  class Client
    attr_reader :connection

    def initialize
      @connection = Client.make_connection(ENV['TINKOFF_OPENAPI_URL'])
    end

    def portfolio
      get_data('portfolio')
    end

    def portfolio_currencies
      get_data('portfolio/currencies')
    end

    def market_candles(params = {})
      get_data('market/candles', params)
    end

  private
    def get_data(url, params = {})
      request(:get, url, params)
    end

    def request(method, url, params = {})
      response = connection.public_send(method, url, params)

      if response.success?
        response.body
      else
        handle_error(response)
      end
    end

    def handle_error(response)
      raise(
        ClientError,
        "Tinkoff responded with HTTP #{response.status}: #{response.body.ai}"
      )
    end

    class << self
      def make_connection(url)
        Faraday.new(url: url) do |builder|
          builder.request :json
          builder.authorization :Bearer, ENV['TINKOFF_OPENAPI_TOKEN']
          builder.response :oj, content_type: 'application/json'
          builder.adapter  Faraday.default_adapter
        end
      end
    end
  end
end
