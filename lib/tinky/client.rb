require 'faraday'
require 'faraday_middleware'
require 'faraday_middleware/parse_oj'

module Tinky
  class Client
    NAMESPACE = 'tinkoff.public.invest.api.contract.v1'.freeze

    attr_reader :connection

    def initialize
      @connection = self.class.make_connection(api_url, api_token)
    end

    def portfolio(currency_mode:)
      account_id = first_account_id
      request_data('OperationsService/GetPortfolio',
                   { accountId: account_id, currency: currency_mode })
    end

    def currencies
      request_data('InstrumentsService/Currencies', instruments_request_params)
    end

    def user_info
      request_data('UsersService/GetInfo')
    end

    def accounts
      request_data('UsersService/GetAccounts', { status: 'ACCOUNT_STATUS_OPEN' })
    end

    def dividends(instrument_id:, from: nil, to: nil)
      body = { instrumentId: instrument_id }
      body[:from] = from.utc.iso8601(3) if from
      body[:to] = to.utc.iso8601(3) if to
      request_data('InstrumentsService/GetDividends', body)
    end

    def bond_coupons(instrument_id:, from: nil, to: nil)
      body = { instrumentId: instrument_id }
      body[:from] = from.utc.iso8601(3) if from
      body[:to] = to.utc.iso8601(3) if to
      request_data('InstrumentsService/GetBondCoupons', body)
    end

    # Returns instrument info (including :name) by figi or instrument_uid.
    # id_type: :figi or :uid
    def get_instrument(id:, id_type: :figi)
      type = id_type == :uid ? 'INSTRUMENT_ID_TYPE_UID' : 'INSTRUMENT_ID_TYPE_FIGI'
      request_data('InstrumentsService/GetInstrumentBy', { idType: type, id: id })
    end

  private

    def api_url
      ENV.fetch('TINVEST_OPENAPI_URL') { raise ClientError, 'TINVEST_OPENAPI_URL is not set' }
    end

    def api_token
      ENV.fetch('TINVEST_OPENAPI_TOKEN') { raise ClientError, 'TINVEST_OPENAPI_TOKEN is not set' }
    end

    def first_account_id
      list = accounts[:accounts]
      raise ClientError, 'No open accounts found' if list.nil? || list.empty?

      list.first[:id]
    end

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
      body_str = response.body.is_a?(Hash) ? response.body.to_s : response.body.inspect
      message = "Tinkoff API error HTTP #{response.status}: #{body_str}"
      raise ClientError.new(message, status: response.status, response_body: response.body)
    end

    def instruments_request_params
      {
        instrumentStatus:   'INSTRUMENT_STATUS_UNSPECIFIED',
        instrumentExchange: 'INSTRUMENT_EXCHANGE_UNSPECIFIED'
      }
    end

    class << self
      def make_connection(url, token)
        Faraday.new(url:, ssl: { verify: false }) do |builder|
          builder.request :json
          builder.authorization :Bearer, token
          builder.response :oj, content_type: 'application/json'
          builder.adapter  Faraday.default_adapter
        end
      end
    end
  end
end
