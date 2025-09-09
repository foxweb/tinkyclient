require './config/dotenv'
require './config/oj'

require 'bigdecimal/util'

require 'tty/table'

require 'pry'
require 'awesome_print'

require './lib/tinky/client'
require './lib/tinky/client_error'

module Tinky # rubocop:disable Metrics/ModuleLength
  CURRENCIES = {
    rub: { symbol: '₽', ticker: nil },
    usd: { symbol: '$', ticker: 'USD000UTSTOM' },
    eur: { symbol: '€', ticker: 'EUR_RUB__TOM' }
  }.freeze

  class << self
    def portfolio
      items = positions.sort_by { |i| i[:type] } # .select{|i| i[:ticker] == 'TIPO2'}

      puts "\nPortfolio:"
      puts portfolio_table(items)

      puts "\nTotal amount summary:"

      # exchange_rates(items)
      binding.pry
      puts summary_table(full_summary.values)

      print_timestamp
    end

    def watch_portfolio
      print `tput smcup`

      loop do
        items = positions

        print `clear`

        puts 'Portfolio:'
        puts portfolio_table(items)
        puts

        puts 'Total amount summary:'

        puts summary_table(full_summary.values)

        print_timestamp

        sleep 2
      end
    end

    def restore_tty
      print `tput rmcup`
    end

    def wallet
      items = client.portfolio_currencies.dig(:payload, :currencies)

      puts "\nWallet:"
      puts wallet_table(items)

      print_timestamp
    end

    def portfolio_table(items)
      prev_type = items.first[:instrumentType]

      table = TTY::Table.new(
        header: ['Type', 'Name', 'Amount', 'Avg. buy', 'Current price', 'Yield', 'Yield %']
      )

      items.each do |item|
        # table << :separator if item[:instrumentType] != prev_type
        table << row_data(item)
        prev_type = item[:instrumentType]
      end

      table.render(:unicode, padding: [0, 1, 0, 1])
    end

    def wallet_table(items)
      table = TTY::Table.new(header: %w[Currencies])

      items.each do |item|
        currency = CURRENCIES[item[:currency].to_sym]
        formatted_value = format('%.2f %s', item[:balance], currency[:symbol])

        table << [
          {
            value:     pastel.bold(formatted_value),
            alignment: :right
          }
        ]
      end

      table.render(:unicode, padding: [0, 1, 0, 1])
    end

    def total_amount(positions) # rubocop:disable Metrics/AbcSize
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

    def exchange_rates(positions)
      # calculate exchange rate in RUB by currency
      currencies(positions).reduce({}) do |result, c|
        last_currency_candle = client.market_candles(candles_params(c[:figi]))
        rate = last_currency_candle.dig(:payload, :candles).last[:c]

        # get currency code by ticker
        currency = currency_by_ticker(c[:ticker])

        result.merge(currency => rate)
      end
    end

    def candles_params(figi)
      current_time = Time.now
      {
        figi:,
        from:     (current_time - (24 * 3600 * 3)).iso8601,
        to:       current_time.iso8601,
        interval: 'hour'
      }
    end

    def summary(items, rates) # rubocop:disable Metrics/AbcSize
      total = Hash.new { |h, k| h[k] = [0, '₽'] }

      total_amount(items).each_with_object(total) do |(key, value), memo|
        rate = rates.fetch(key, 1)

        memo[:price][0] += value[:price] * rate
        memo[:yield][0] += value[:yield] * rate
        memo[:total][0] += value[:total] * rate
      end
    end

    def full_summary
      {
        total_purchases: [1, '₽'],
        expected_yield:  [1, '₽'],
        expected_total:  [1, '₽'],
        total_yield:     decorate_price(portfolio_data[:expectedYield]),
        total_with_rub:  decorate_price(portfolio_data[:totalAmountPortfolio])
      }
    end

  private
    def client
      Client.new
    end

    def pastel
      Pastel.new
    end

    def portfolio_data
      @portfolio_data ||= client.portfolio
    end

    def row_data(item)
      currency = item[:averagePositionPrice][:currency]
      [
        item[:instrumentType].upcase,
        decorate_name(item[:ticker]),
        { value: decorate_amount(item[:quantity][:units]), alignment: :right },
        {
          value:     decorate_price(item[:averagePositionPrice]).join(' '),
          alignment: :right
        },
        {
          value:     decorate_price(item[:currentPrice]).join(' '),
          alignment: :right
        },
        { value: decorate_yield(item[:expectedYield], currency), alignment: :right },
        { value: decorate_yield_percent(item), alignment: :right }
      ]
    end

    def decorate_yield(expected_yield, currency = 'usd')
      value = expected_yield[:units].to_f
      currency = CURRENCIES[currency.to_sym]

      formatted_value = format('%+.2f %s', value.round(2), currency[:symbol])
      pastel.decorate(formatted_value, yield_color(value))
    end

    def decorate_yield_percent(item)
      total = item.dig(:averagePositionPrice, :units).to_d * item[:quantity][:units].to_d

      value = if item[:averagePositionPrice][:units].to_d.zero? || item[:quantity][:units].to_d.zero?
        0.0
      else
        item.dig(:expectedYield, :units).to_d / total.to_d * 100
      end

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
        "#{name[0..28]}…"
      else
        name
      end

      pastel.bold(stripped_name)
    end

    def decorate_price(price)
      value = price[:units].to_d + (price[:nano].to_d / (10**9))
      currency_symbol = price.key?(:currency) ? CURRENCIES[price[:currency].to_sym][:symbol] : '%'
      [value.to_f.round(2), currency_symbol]
    end

    def print_timestamp
      puts "\nLast updated: #{Time.now}\n\n"
    end

    def currency_by_ticker(ticker)
      CURRENCIES.select { |_, v| v[:ticker] == ticker }.keys.first
    end

    def positions
      portfolio_data[:positions]
    end

    # select only currencies positions (wallet)
    def currencies(positions)
      positions.select do |position|
        position[:instrumentType] == 'Currency'
      end
    end

    def decorate_summary(items)
      items.map do |item|
        value = format('%+.2f %s', item[0].to_f.round(2), item[1])
        {
          value:     pastel.decorate(value, yield_color(item[0]), :bold),
          alignment: :right
        }
      end
    end

    def summary_table(items)
      table = TTY::Table.new(
        header: [
          'Total Purchases',
          'Expected Yield',
          'Expected Total',
          'Yield %',
          'Total + RUB balance'
        ]
      )
      table << decorate_summary(items)
      table.render(:unicode, padding: [0, 1, 0, 1])
    end

    def rub_balance
      client
        .portfolio_currencies
        .dig(:payload, :currencies)
        .find { |i| i[:currency] == 'RUB' }[:balance].to_d
    end
  end
end

Signal.trap('INT') do
  Tinky.restore_tty
  exit
end

Signal.trap('TERM') do
  Tinky.restore_tty
  exit
end
