require './config/dotenv'
require './config/oj'

require 'bigdecimal/util'

require 'tty/table'

require 'pry'
require 'awesome_print'

require './lib/tinky/client'
require './lib/tinky/client_error'

module Tinky
  CURRENCIES = {
    RUB: { symbol: '₽', ticker: nil },
    USD: { symbol: '$', ticker: 'USD000UTSTOM' },
    EUR: { symbol: '€', ticker: 'EUR_RUB__TOM' }
  }.freeze

  class << self
    def portfolio
      items = positions
      prev_type = items.first[:instrumentType]

      table = portfolio_table

      items.each do |item|
        # table << :separator if item[:instrumentType] != prev_type
        table << row_data(item)
        prev_type = item[:instrumentType]
      end

      puts table.render(:ascii, padding: [0, 1, 0, 1])
      puts "\n\nTotal amount summary:"
      puts summary_table(summary(items).values)
      print_timestamp
    end

    def wallet
      items = client.portfolio_currencies.dig(:payload, :currencies)

      table = TTY::Table.new(header: %w[Currencies])

      items.each do |item|
        currency = CURRENCIES[item[:currency].to_sym]
        formatted_value = format('%.2f %s', item[:balance], currency[:symbol])

        table << [{ value: formatted_value, alignment: :right }]
      end

      puts table.render(:ascii, padding: [0, 1, 0, 1])
      print_timestamp
    end

    # rubocop:disable Metrics/AbcSize
    def total_amount(positions)
      total = Hash.new do |h, k|
        h[k] = { price: 0, yield: 0, total: 0 }
      end

      positions.each_with_object(total) do |item, result|
        currency = item.dig(:averagePositionPrice, :currency).to_sym
        avg_price = item.dig(:averagePositionPrice, :value).to_d
        price = avg_price * item[:balance].to_d
        expected_yield = item.dig(:expectedYield, :value).to_d

        result[currency][:price] += price
        result[currency][:yield] += expected_yield
        result[currency][:total] += price + expected_yield
      end
    end
    # rubocop:enable Metrics/AbcSize

    def exchange_rates(positions)
      # calculate exchange rate in RUB by currency
      currencies(positions).reduce({}) do |result, c|
        balance = c[:balance].to_d # currency amount in EUR, USD
        avg_price = c.dig(:averagePositionPrice, :value).to_d # price inRUB
        sum = avg_price * balance # sum in RUB
        expected_yield = c.dig(:expectedYield, :value).to_d # profit in RUB
        total = sum + expected_yield # avg. buy price + profit in RUB
        rate = (total / balance).round(4) # exchange rate in RUB

        # get currency code by ticker
        currency = currency_by_ticker(c[:ticker])

        result.merge(currency => rate)
      end
    end

    def summary(positions)
      rates = exchange_rates(positions)

      total = Hash.new { |h, k| h[k] = 0 }

      total_amount(positions).each_with_object(total) do |item, memo|
        rate = rates[item.first] || 1

        memo[:price] += item[1][:price] * rate
        memo[:yield] += item[1][:yield] * rate
        memo[:total] += item[1][:total] * rate
      end
    end

  private
    def client
      Client.new
    end

    def pastel
      Pastel.new
    end

    def portfolio_table
      TTY::Table.new(header: %w[Type Name Amount Avg.\ price Yield Yield\ %])
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

      formatted_value = format('%+.2f %s', value, currency[:symbol])
      pastel.decorate(formatted_value, yield_color(value))
    end

    def decorate_yield_percent(item)
      total = item.dig(:averagePositionPrice, :value).to_d * item[:balance].to_d
      value = item.dig(:expectedYield, :value).to_d / total.to_d * 100

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
      format('%.2f %s', price[:value], currency[:symbol])
    end

    def print_timestamp
      puts "Last updated: #{Time.now}"
    end

    def currency_by_ticker(ticker)
      CURRENCIES.select { |_, v| v[:ticker] == ticker }.keys.first
    end

    def positions
      portfolio_data.dig(:payload, :positions)
    end

    # select only currencies positions (wallet)
    def currencies(positions)
      positions.select do |position|
        position[:instrumentType] == 'Currency'
      end
    end

    def decorate_summary(items)
      items.map do |item|
        {
          value:     pastel.decorate(
            format('%+.2f ₽', item.to_f.round(2)), yield_color(item), :bold
          ),
          alignment: :right
        }
      end
    end

    def summary_table(values)
      table = TTY::Table.new(header: %w[Avg.\ buy\ price Yield Total])
      table << decorate_summary(values)
      table.render(:ascii, padding: [0, 1, 0, 1])
    end
  end
end
