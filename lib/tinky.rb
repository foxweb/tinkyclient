require './config/dotenv'
require './config/oj'
require 'bigdecimal/util'
require 'tty/table'
require 'pry'
require 'awesome_print'
require './lib/tinky/version'
require './lib/tinky/client'
require './lib/tinky/client_error'

module Tinky # rubocop:disable Metrics/ModuleLength
  # ISO 4217 currencies supported by T-Invest API (InstrumentsService/Currencies).
  # Keys: lowercase ISO code; value: { symbol: display symbol, ticker: exchange ticker if known }.
  CURRENCIES = {
    rub: { symbol: '₽', ticker: 'RUB000UTSTOM' },
    usd: { symbol: '$', ticker: 'USD000UTSTOM' },
    eur: { symbol: '€', ticker: 'EUR_RUB__TOM' },
    gbp: { symbol: '£', ticker: 'GBPRUB_TOM' },
    chf: { symbol: 'Fr', ticker: 'CHFRUB_TOM' },
    jpy: { symbol: '¥', ticker: 'JPYRUB_TOM' },
    cny: { symbol: '¥', ticker: 'CNYRUB_TOM_CETS' },
    hkd: { symbol: 'HK$', ticker: 'HKDRUB_TOM' },
    try: { symbol: '₺', ticker: 'TRYRUB_TOM_CETS' },
    kzt: { symbol: '₸', ticker: 'KZTRUB_TOM' },
    byn: { symbol: 'Br', ticker: 'BYNRUB_TOM' },
    aud: { symbol: 'A$', ticker: 'AURRUB_TOM' },
    amd: { symbol: '֏', ticker: 'AMDRUB_TOM' },
    gel: { symbol: '₾', ticker: 'GELRUB_TOM' },
    inr: { symbol: '₹', ticker: 'INRRUB_TOM' },
    uah: { symbol: '₴', ticker: 'UAHRUB_TOM' },
    uzs: { symbol: 'soʻm', ticker: 'UZSRUB_TOM' },
    aed: { symbol: 'د.إ', ticker: 'AEDRUB_TOM' },
    cad: { symbol: 'C$', ticker: 'CADRUB_TOM' },
    sgd: { symbol: 'S$', ticker: 'SGDRUB_TOM' },
    thb: { symbol: '฿', ticker: 'THBRUB_TOM' }
  }.freeze

  CURRENCY_MODE = :rub # NOTE: for further development

  class << self # rubocop:disable Metrics/ClassLength
    def portfolio
      print_portfolio_section
      print_summary_section
      print_future_payments_section
      print_user_info_section
      print_account_section
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
      puts
      puts 'Wallet:'
      puts wallet_table(currency_positions)

      print_timestamp
    end

    def print_timestamp
      puts
      puts "Last updated: #{Time.now}\n\n"
    end

    def print_portfolio_section
      puts
      puts 'Portfolio:'
      puts portfolio_table(positions)
      puts
      puts "❌ - ticker is blocked for trading\n"
    end

    def print_summary_section
      puts
      puts 'Total amount summary:'
      puts summary_table(summary_data.values)
    end

    def print_future_payments_section
      puts
      puts 'Future payments (dividends & coupons):'
      puts future_payments_table
    end

    def print_user_info_section
      puts
      puts 'User info:'
      puts user_info_table
    end

    def print_account_section
      puts
      puts 'Account info:'
      puts account_table
    end

    def portfolio_table(items)
      prev_type = items.first[:instrumentType]

      table = TTY::Table.new(
        header: ['Type', 'Name', 'Amount', 'Avg. buy', 'Current price', 'Buy sum', 'Current sum',
                 'Yield', 'Yield %', 'Daily %']
      )

      items.each do |item|
        # BUG: separator line isn't working according github issue: https://github.com/piotrmurach/tty-table/issues/31
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

    def user_info_table
      table = TTY::Table.new
      user_info_rows.each do |row|
        table << row
      end
      table.render(:unicode, padding: [0, 1, 0, 1])
    end

    def account_table
      table = TTY::Table.new
      account_rows.each do |row|
        table << row
      end
      table.render(:unicode, padding: [0, 1, 0, 1])
    end

    def summary_data
      expected_yield = total_without_currencies / (100 + total_yield[0]) * total_yield[0]
      symbol = CURRENCIES[CURRENCY_MODE][:symbol]
      {
        total_purchases: [total_purchases, symbol],
        expected_yield:  [expected_yield, symbol],
        expected_total:  [total_without_currencies, symbol],
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
      @client ||= Client.new
    end

    def pastel
      @pastel ||= Pastel.new
    end

    def portfolio_data
      @portfolio_data ||= client.portfolio(currency_mode: CURRENCY_MODE)
    end

    def user_data
      @user_data ||= client.user_info
    end

    def account_data
      @account_data ||= client.accounts[:accounts].first
    end

    def row_data(item)
      currency = item[:averagePositionPrice][:currency]
      amount = decorate_amount(item[:quantity])
      avg_buy_price = decorate_price(item[:averagePositionPrice])
      current_price = decorate_price(item[:currentPrice])
      buy_sum = [(avg_buy_price[0] * amount).round(2), avg_buy_price[1]]
      current_sum = [(current_price[0] * amount).round(2), current_price[1]]

      [
        item[:instrumentType].upcase,
        decorate_name(item),
        { value: amount, alignment: :right },
        { value: avg_buy_price.join(' '), alignment: :right },
        { value: current_price.join(' '), alignment: :right },
        { value: buy_sum.join(' '), alignment: :right },
        { value: current_sum.join(' '), alignment: :right },
        { value: decorate_yield(item[:expectedYield], currency), alignment: :right },
        { value: decorate_yield_percent(item, :expectedYield), alignment: :right },
        { value: decorate_yield_percent(item, :dailyYield), alignment: :right }
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

    def decorate_yield_percent(item, value = :expectedYield)
      yield_percent = if zero_item?(item)
        0.0
      else
        decorate_price(item[value])[0].to_d / total_buy(item).to_d * 100
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
      result = amount[:units].to_i + (amount[:nano].to_f / (10**9)).to_d
      result == amount[:units].to_i ? amount[:units].to_i : result.to_f
    end

    def decorate_name(item)
      name = instrument_name_for(item) || item[:ticker].to_s
      stripped_name = if name.length > 29
        "#{name[0..28]}…"
      else
        name
      end

      pastel.bold(stripped_name + (' ❌' if item[:blocked]).to_s)
    end

    def instrument_name_for(item)
      id = item[:instrumentUid] || item[:instrument_uid] || item['instrumentUid'] || item['instrument_uid'] || item[:figi]
      return nil unless id

      instrument_names[id]
    end

    def instrument_names
      @instrument_names ||= build_instrument_names
    end

    def build_instrument_names
      names = {}
      securities = positions.reject { |p| p[:instrumentType].to_s == 'currency' }
      securities.each do |pos|
        uid = pos[:instrumentUid] || pos[:instrument_uid] || pos['instrumentUid'] || pos['instrument_uid']
        figi = pos[:figi]
        id = uid.to_s.empty? ? figi : uid
        id_type = uid.to_s.empty? ? :figi : :uid
        next if id.nil? || id.empty? || names.key?(id)

        resp = client.get_instrument(id: id, id_type: id_type)
        inst = resp[:instrument] || resp['instrument']
        next unless inst

        name = inst[:name] || inst['name']
        next unless name

        names[id] = name
        names[figi] = name if figi && figi != id
      rescue ClientError
        # skip failed lookups
      end
      names
    end

    def decorate_price(price)
      value = price[:units].to_d + (price[:nano].to_d / (10**9))
      currency_symbol = price.key?(:currency) ? currency_symbol_for(price[:currency]) : '%'
      [value.to_f.round(2), currency_symbol]
    end

    def currency_symbol_for(currency_code)
      return '%' if currency_code.nil? || currency_code.to_s.empty?

      key = currency_code.to_s.downcase.to_sym
      CURRENCIES.dig(key, :symbol) || currency_code.to_s.upcase
    end

    def positions
      @positions ||= portfolio_data[:positions]
    end

    def currency_positions
      positions.select { |i| i[:instrumentType] == 'currency' }
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
          'Wallet',
          'Total + wallet'
        ]
      )
      table << decorate_summary(items)
      table.render(:unicode, padding: [0, 1, 0, 1])
    end

    def future_payments_table
      items = future_payments
      return pastel.dim("(no future payments in the next 2 years)\n") if items.empty?

      table = TTY::Table.new(
        header: %w[Date Instrument Type Amount Qty]
      )
      items.each do |item|
        name = (item[:name] || item[:ticker]).to_s
        name = "#{name[0..46]}…" if name.length > 47
        table << [
          item[:date],
          name,
          item[:type] == :dividend ? 'Dividend' : 'Coupon',
          item[:amount_str],
          { value: item[:quantity].to_s, alignment: :right }
        ]
      end
      table.render(:unicode, padding: [0, 1, 0, 1])
    end

    def future_payments
      @future_payments ||= build_future_payments
    end

    def build_future_payments
      instrument_names # preload names so we have them for payments
      from_time = Time.now.utc
      to_time = from_time + (90 * 24 * 3600)
      list = []
      securities = positions.reject { |p| p[:instrumentType].to_s == 'currency' }
      securities.each do |pos|
        id = pos[:instrumentUid] || pos[:instrument_uid] || pos['instrumentUid'] || pos['instrument_uid'] || pos[:figi]
        next unless id

        qty = decorate_amount(pos[:quantity]).to_f
        qty = qty.to_i if qty == qty.to_i
        ticker = (pos[:ticker] || pos[:figi] || '?').to_s
        display_name = instrument_names[id] || instrument_names[pos[:figi]] || ticker

        case pos[:instrumentType].to_s
        when 'share', 'etf'
          fetch_dividends(id, from_time, to_time, display_name, qty, list)
        when 'bond'
          fetch_bond_coupons(id, from_time, to_time, display_name, qty, list)
        end
      rescue ClientError => e
        warn "Warning: #{ticker} — #{e.message}" if ENV['TINKY_DEBUG']
      end
      list.sort_by { |x| x[:date] }
    end

    def fetch_dividends(instrument_id, from_time, to_time, display_name, qty, list)
      data = client.dividends(instrument_id: instrument_id, from: from_time, to: to_time)
      dividends = data[:dividends] || data['dividends'] || []
      dividends.each do |d|
        next if d[:dividendType].to_s == 'Cancelled' || d['dividendType'].to_s == 'Cancelled'

        payment_date = parse_timestamp(d[:paymentDate] || d['paymentDate'])
        next if payment_date.nil? || payment_date < from_time

        net = d[:dividendNet] || d['dividendNet'] || {}
        amount = money_units(net) * qty
        curr = (net[:currency] || net['currency'] || 'rub').to_s.upcase
        list << {
          date:       payment_date.strftime('%Y-%m-%d'),
          name:       display_name,
          ticker:     display_name,
          type:       :dividend,
          amount_str: format('%.2f %s', amount, curr == 'RUB' ? '₽' : curr),
          quantity:   qty
        }
      end
    end

    def fetch_bond_coupons(instrument_id, from_time, to_time, display_name, qty, list)
      data = client.bond_coupons(instrument_id: instrument_id, from: from_time, to: to_time)
      events = data[:events] || data['events'] || []
      events.each do |c|
        coupon_date = parse_timestamp(c[:couponDate] || c['couponDate'])
        next if coupon_date.nil? || coupon_date < from_time

        pay_one = c[:payOneBond] || c['payOneBond'] || {}
        amount = money_units(pay_one) * qty
        curr = (pay_one[:currency] || pay_one['currency'] || 'rub').to_s.upcase
        list << {
          date:       coupon_date.strftime('%Y-%m-%d'),
          name:       display_name,
          ticker:     display_name,
          type:       :coupon,
          amount_str: format('%.2f %s', amount, curr == 'RUB' ? '₽' : curr),
          quantity:   qty
        }
      end
    end

    def parse_timestamp(ts)
      return nil unless ts

      if ts.is_a?(String)
        Time.parse(ts)
      elsif ts.is_a?(Hash)
        sec = ts[:seconds] || ts['seconds']&.to_i
        nano = ts[:nanos] || ts['nanos']&.to_i || 0
        sec ? Time.at(sec, nano, :nsec).utc : nil
      end
    end

    def money_units(money)
      return 0.to_d unless money.is_a?(Hash)

      u = (money[:units] || money['units'] || 0).to_d
      n = (money[:nano] || money['nanos'] || money['nano'] || 0).to_i
      u + (n / 1e9)
    end

    def symbol_by_ticker(ticker)
      pair = CURRENCIES.values.find { |c| c[:ticker] == ticker.to_s }
      return pair[:symbol] if pair

      # Resolve from API Currencies (ticker may differ from CURRENCIES, e.g. GBPRUB_TOM_CETS)
      iso = available_currencies_ticker_to_iso[ticker.to_s]
      iso ? currency_symbol_for(iso) : '?'
    end

    def available_currencies_ticker_to_iso
      @available_currencies_ticker_to_iso ||= available_currencies.each_with_object({}) do |(iso, data), memo|
        t = data[:ticker] || data['ticker']
        memo[t.to_s] = iso.to_s if t
      end
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

    def user_info_rows
      [
        [pastel.bold('User ID'), user_data[:userId]],
        [pastel.bold('Premium status'), user_data[:premStatus] ? '✅' : '❌'],
        [pastel.bold('Qual status'), user_data[:qualStatus] ? '✅' : '❌'],
        [pastel.bold('Tariff'), user_data[:tariff].capitalize],
        [pastel.bold('Risk level'), user_data[:riskLevelCode].capitalize]
      ]
    end

    def account_rows
      [
        [pastel.bold('Account ID'), account_data[:id]],
        [pastel.bold('Type'), account_data[:type]],
        [pastel.bold('Name'), account_data[:name]],
        [pastel.bold('Opened at'), Time.parse(account_data[:openedDate]).strftime('%d %b %Y')],
        [pastel.bold('Access level'), account_data[:accessLevel]]
      ]
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
