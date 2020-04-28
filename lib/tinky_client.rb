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
      portfolio_data.dig(:payload, :positions).each do |item|
        portfolio_table << row_data(item)
      end

      puts portfolio_table.render(:ascii, padding: [0, 1, 0, 1])
    end

  private
    def client
      @client ||= Client.new
    end

    def pastel
      @pastel ||= Pastel.new
    end

    def portfolio_table
      @portfolio_table ||= TTY::Table.new(
        header: %w[Type Name Amount Avg.\ price Yield Yield\ %]
      )
    end

    def portfolio_data
      client.portfolio
    end

    def row_data(item)
      [
        item[:instrumentType].upcase,
        decorate_name(item[:name]),
        { value: decorate_amount(item[:balance]), alignment: :right },
        {
          value:     decorate_price(item[:averagePositionPrice]),
          alignment: :right
        },
        { value: decorate_yield(item[:expectedYield]), alignment: :right },
        { value: decorate_yield_percent(item), alignment: :right }
      ]
    end

    def decorate_yield(expected_yield)
      value = expected_yield[:value]
      currency = CURRENCIES[expected_yield[:currency].to_sym]

      formatted_value = format("%+.2f #{currency}", value)
      pastel.decorate(formatted_value, yield_color(value))
    end

    def decorate_yield_percent(item)
      total = item.dig(:averagePositionPrice, :value) * item[:balance]
      value = item.dig(:expectedYield, :value) / total * 100

      formatted_value = format('%+.2f %%', value)
      pastel.decorate(formatted_value, yield_color(value))
    end

    def yield_color(value)
      if value.positive?
        :green
      elsif value.negative?
        :red
      else
        :clear
      end
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

    def decorate_price(price)
      currency = CURRENCIES[price[:currency].to_sym]
      format('%.2f %s', price[:value], currency)
    end
  end
end
