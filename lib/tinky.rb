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
    rub: { symbol: '₽', ticker: 'RUB000UTSTOM' },
    usd: { symbol: '$', ticker: 'USD000UTSTOM' },
    eur: { symbol: '€', ticker: 'EUR_RUB__TOM' },
    cny: { symbol: '¥', ticker: 'CNYRUB_TOM_CETS' },
    try: { symbol: '₺', ticker: 'TRYRUB_TOM_CETS' }
  }.freeze

  class << self # rubocop:disable Metrics/ClassLength
    def portfolio
      puts "\nPortfolio:"
      puts portfolio_table(positions)

      puts "\nTotal amount summary:"
      puts summary_table(summary_data.values)

      print_timestamp
    end

    def watch_portfolio
      print `tput smcup`

      loop do
        print `clear`

        puts 'Portfolio:'
        puts portfolio_table(positions)
        puts

        puts 'Total amount summary:'
        puts summary_table(summary_data.values)

        print_timestamp

        sleep 2
      end
    end

    def restore_tty
      print `tput rmcup`
    end

    def wallet
      puts "\nWallet:"
      puts wallet_table(currency_positions)

      print_timestamp
    end

    def portfolio_table(items)
      prev_type = items.first[:instrumentType]

      table = TTY::Table.new(
        header: ['Type', 'Name', 'Amount', 'Avg. buy', 'Current price', 'Buy sum', 'Current sum',
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
        currency_symbol = symbol_by_ticker(item[:ticker])
        value = decorate_price(item[:quantity])[0]
        formatted_value = format('%.2f %s', value, currency_symbol)

        table << [
          {
            value:     pastel.bold(formatted_value),
            alignment: :right
          }
        ]
      end

      table.render(:unicode, padding: [0, 1, 0, 1])
    end

    def summary_data
      expected_yield = total_without_currencies / (100 + total_yield[0]) * total_yield[0]

      {
        total_purchases: [total_purchases, '₽'],
        expected_yield:  [expected_yield, '₽'],
        expected_total:  [total_without_currencies, '₽'],
        total_yield:     total_yield,
        rub_balance:     rub_balance,
        total_with_rub:  decorate_price(portfolio_data[:totalAmountPortfolio])
      }
    end

    def available_currencies
      @available_currencies ||= client.currencies[:instruments].reduce({}) do |memo, currency|
        data = currency.slice(:ticker, :name)
        memo.merge!(currency[:isoCurrencyName].to_sym => data)
      end
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

    def row_data(item) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      currency = item[:averagePositionPrice][:currency]
      amount = decorate_amount(item[:quantity][:units]).to_i
      avg_buy_price = decorate_price(item[:averagePositionPrice])
      current_price = decorate_price(item[:currentPrice])
      buy_sum = [(avg_buy_price[0] * amount).round(2), avg_buy_price[1]]
      current_sum = [(current_price[0] * amount).round(2), current_price[1]]

      [
        item[:instrumentType].upcase,
        decorate_name(item[:ticker]),
        { value: amount, alignment: :right },
        { value: avg_buy_price.join(' '), alignment: :right },
        { value: current_price.join(' '), alignment: :right },
        { value: buy_sum.join(' '), alignment: :right },
        { value: current_sum.join(' '), alignment: :right },
        { value: decorate_yield(item[:expectedYield], currency), alignment: :right },
        { value: decorate_yield_percent(item), alignment: :right }
      ]
    end

    def decorate_yield(expected_yield, currency = 'usd')
      value = expected_yield[:units].to_d + (expected_yield[:nano].to_d / (10**9))
      currency = CURRENCIES[currency.to_sym]

      formatted_value = format('%+.2f %s', value.round(2), currency[:symbol])
      pastel.decorate(formatted_value, yield_color(value))
    end

    def zero_item?(item)
      item[:averagePositionPrice][:units].to_d.zero? || item[:quantity][:units].to_d.zero?
    end

    def total_buy(item)
      decorate_price(item[:averagePositionPrice])[0] * item[:quantity][:units].to_d
    end

    def decorate_yield_percent(item)
      yield_percent = if zero_item?(item)
        0.0
      else
        decorate_price(item[:expectedYield])[0].to_d / total_buy(item).to_d * 100
      end

      formatted_value = format('%+.2f %%', yield_percent.round(2))
      pastel.decorate(formatted_value, yield_color(yield_percent))
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

    def positions
      portfolio_data[:positions]
    end

    def currency_positions
      portfolio_data[:positions].select { |i| i[:instrumentType] == 'currency' }
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
          'RUB balance',
          'Total + RUB balance'
        ]
      )
      table << decorate_summary(items)
      table.render(:unicode, padding: [0, 1, 0, 1])
    end

    def symbol_by_ticker(ticker)
      pair = CURRENCIES.values.find { |c| c[:ticker] == ticker.to_s }
      pair&.fetch(:symbol, nil) || '?'
    end

    def total_yield
      @total_yield ||= decorate_price(portfolio_data[:expectedYield])
    end

    def total_purchases
      total_without_currencies / (100 + total_yield[0]) * 100
    end

    def total_without_currencies
      @total_without_currencies ||=
        decorate_price(portfolio_data[:totalAmountPortfolio])[0] - rub_balance[0]
    end

    def rub_balance
      decorate_price(portfolio_data[:totalAmountCurrencies])
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
