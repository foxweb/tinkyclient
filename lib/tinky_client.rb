require './config/dotenv'
require './config/oj'

require 'faraday'
require 'faraday_middleware'
require 'faraday_middleware/parse_oj'

require 'tty/table'

require 'pry'
require 'awesome_print'

module TinkyClient
  CURRENCIES = { RUB: '₽', USD: '$', EUR: '€' }.freeze

  class Client
    attr_reader :connection

    def initialize
      @connection = Client.make_connection(ENV['TINKOFF_OPENAPI_URL'])
    end

    def portfolio
      get_data('portfolio')
    end

  private
    def get_data(url)
      request(:get, url)
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

  class ClientError < StandardError; end

  class << self
    def portfolio
      puts
      summary = client.portfolio
      table = TTY::Table.new(header: %w[Type Name Amount Yield])

      summary.dig(:payload, :positions).each do |p|
        currency = CURRENCIES[p[:expectedYield][:currency].to_sym]
        decorated_yield = decorate_value(p[:expectedYield][:value], currency)
        table << [
          p[:instrumentType].upcase,
          decorate_name(p[:name]),
          { value: decorate_amount(p[:balance]), alignment: :right },
          { value: decorated_yield, alignment: :right }
        ]
      end

      puts table.render(:ascii, padding: [0, 1, 0, 1])
      puts
    end

  private

    def client
      @client ||= Client.new
    end

    def pastel
      @pastel ||= Pastel.new
    end

    def decorate_value(value, currency)
      color = if value.positive?
        :green
      elsif value.negative?
        :red
      else
        :clear
      end

      formatted_value = format("%+.2f #{currency}", value)
      pastel.decorate(formatted_value, color)
    end

    def decorate_amount(amount)
      if amount == amount.to_i
        amount.round
      else
        amount
      end
    end

    def decorate_name(name)
      stripped_name = if name.length > 29
        name[0..28] + '…'
      else
        name
      end

      pastel.bold(stripped_name)
    end
  end
end
