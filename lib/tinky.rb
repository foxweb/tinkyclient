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
    RUB: { symbol: '₽', ticker: nil },
    USD: { symbol: '$', ticker: 'USD000UTSTOM' },
    EUR: { symbol: '€', ticker: 'EUR_RUB__TOM' }
  }.freeze

  class << self
    def portfolio
      items = positions

      puts "\nPortfolio:"
      puts portfolio_table(items)

      puts "\nTotal amount summary:"

      rates = exchange_rates(items)
      summary_data = full_summary(items, rates).values
      puts summary_table(summary_data)

      print_timestamp
    end

    def total_banner
      items = positions
      rates = exchange_rates(items)
      summary = full_summary(items, rates)

      total = format('%.2f р.', summary[:total_with_rub][0].to_f.round(2))
      percent = format('%+.2f %%', summary[:yield_percent][0].to_f.round(2))

      print `toilet -w 100 #{total} #{percent}`
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

        rates = exchange_rates(items)
        summary_data = full_summary(items, rates).values
        puts summary_table(summary_data)

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
        header: ['Type', 'Name', 'Amount', 'Avg. buy', 'Current price',
                 'Yield', 'Yield %']
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
        figi:     figi,
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

    def full_summary(items, rates)
      result = summary(items, rates)

      result.merge(
        yield_percent:  [result[:yield][0] / result[:price][0] * 100, '%'],
        total_with_rub: [result[:total][0] + rub_balance, '₽']
      )
    end

  private
    def client
      Client.new
    end

    def pastel
      Pastel.new
    end

    def portfolio_data
      client.portfolio
    end

    def sell_price(item)
      balance = item[:balance].to_d
      avg_buy_price = item[:averagePositionPrice][:value].to_d
      expected_yield = item[:expectedYield][:value].to_d

      {
        value:    ((balance * avg_buy_price) + expected_yield) / balance,
        currency: item[:averagePositionPrice][:currency]
      }
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
        {
          value:     decorate_price(sell_price(item)),
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
        "#{name[0..28]}…"
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
      puts "\nLast updated: #{Time.now}\n\n"
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
