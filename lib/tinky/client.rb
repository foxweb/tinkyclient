require 'faraday'
require 'faraday_middleware'
require 'faraday_middleware/parse_oj'

module Tinky
  class Client
    NAMESPACE = 'tinkoff.public.invest.api.contract.v1'.freeze
    attr_reader :connection

    def initialize
      @connection = Client.make_connection(ENV.fetch('TINVEST_OPENAPI_URL', nil))
    end

    def portfolio(currency_mode:)
      account_id = accounts[:accounts].first[:id]
      request_data('OperationsService/GetPortfolio',
                   { accountId: account_id, currency: currency_mode })
    end

    def currencies
      request_data('InstrumentsService/Currencies',
                   { instrumentStatus:   'INSTRUMENT_STATUS_UNSPECIFIED',
                     instrumentExchange: 'INSTRUMENT_EXCHANGE_UNSPECIFIED' })
    end

    def user_info
      request_data('UsersService/GetInfo')
    end

    def accounts
      request_data('UsersService/GetAccounts', { status: 'ACCOUNT_STATUS_OPEN' })
    end

  private
    def request_data(url, params = {})
      request(:post, [NAMESPACE, url].join('.'), params)
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
        Faraday.new(url:, ssl: { verify: false }) do |builder|
          builder.request :json
          builder.authorization :Bearer, ENV.fetch('TINVEST_OPENAPI_TOKEN', nil)
          builder.response :oj, content_type: 'application/json'
          builder.adapter  Faraday.default_adapter
        end
      end
    end
  end
end
