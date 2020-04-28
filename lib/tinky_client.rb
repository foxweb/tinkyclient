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

    def portfolio_currencies
      get_data('portfolio/currencies')
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
      positions = portfolio_data.dig(:payload, :positions)

      prev_type = positions.first[:instrumentType]

      positions.each do |item|
        # portfolio_table << :separator if item[:instrumentType] != prev_type
        portfolio_table << row_data(item)
        prev_type = item[:instrumentType]
      end

      puts portfolio_table.render(:ascii, padding: [0, 1, 0, 1])
      print_timestamp
    end

    def portfolio_currencies
      items = client.portfolio_currencies.dig(:payload, :currencies)

      table = TTY::Table.new(header: %w[Currencies])

      items.each do |item|
        currency = CURRENCIES[item[:currency].to_sym]
        formatted_value = format('%.2f %s', item[:balance], currency)

        table << [{ value: formatted_value, alignment: :right }]
      end

      puts table.render(:ascii, padding: [0, 1, 0, 1])
      print_timestamp
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

      formatted_value = format('%+.2f %s', value, currency)
      pastel.decorate(formatted_value, yield_color(value))
    end

    def decorate_yield_percent(item)
      total = item.dig(:averagePositionPrice, :value).to_f * item[:balance]
      value = item.dig(:expectedYield, :value).to_f / total * 100

      formatted_value = format('%+.2f %%', value.round(2))
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

    def print_timestamp
      puts "Last updated: #{Time.now}"
    end
  end
end
