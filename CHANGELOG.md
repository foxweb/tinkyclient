# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-02-25

### Added

- **Portfolio section runners** — New bin scripts to run individual portfolio sections: `bin/portfolio-positions`, `bin/summary`, `bin/future-payments`, `bin/user-info`, `bin/account`. Each prints its section and a timestamp. Public methods: `print_portfolio_section`, `print_summary_section`, `print_future_payments_section`, `print_user_info_section`, `print_account_section`, `print_timestamp`.
- **Portfolio: future payments** — In `portfolio` output, a table of upcoming dividends and bond coupons for the next 2 years (T-Invest API: `InstrumentsService/GetDividends`, `InstrumentsService/GetBondCoupons`). Columns: Date, Instrument, Type (Dividend/Coupon), Amount, Qty.
- **Human-readable instrument names** — Portfolio table and future payments show instrument names (e.g. «Сбербанк») instead of ticker codes. Names are loaded via `InstrumentsService/GetInstrumentBy` and cached per run.
- **Extended currency support** — Added support for more currencies in `CURRENCIES`: GBP, CHF, JPY, HKD, KZT, BYN, AUD, AMD, GEL, INR, UAH, UZS, AED, CAD, SGD, THB (symbols and typical MOEX tickers). Wallet and price formatting resolve symbols from API `InstrumentsService/Currencies` when a ticker is not in the static list (`currency_symbol_for`, `symbol_by_ticker` fallback). Unknown currency codes no longer cause errors and are shown as the uppercase code.
- **Versioning** — `Tinky::VERSION`, root `VERSION` file, and `bin/version` to print the current version.

### Changed

- **Portfolio** — Output is built from separate section methods (`print_portfolio_section`, `print_summary_section`, etc.); `portfolio` calls them in sequence. Enables reuse and dedicated bin runners.
- **README** — Documented new bin runners, added table of portfolio sections, updated console examples and «Постоянное обновление портфолио» (built-in `--watch` described; removed references to external `watch` and macOS issues).
- Portfolio output now includes a «Future payments (dividends & coupons)» block before User info.
- Future payments table header: «Ticker» renamed to «Instrument»; values show instrument name when available.
- `decorate_price` uses new `currency_symbol_for` so unknown currencies are displayed safely.
