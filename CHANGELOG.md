# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.2] - 2026-05-21

### Changed

- **Future payments period** — Dividends and bond coupons are loaded through the end of the current calendar year (previously about 90 days ahead).
- **Portfolio table** — Positions are sorted by instrument type and name; separator rows between types are shown again (via `tty-table` fork on branch `separator_bug`).
- **Future payments table** — Header separator restored; after each monthly subtotal, a standard `TTY::Table` `:separator` row is used instead of a custom spacer row.
- **Ruby** — Runtime requirement updated to **4.0.5** (`.ruby-version`, GitHub Actions, Docker image, README).

### Security

- **json** — Direct dependency `>= 2.19.2` to address CVE-2026-33210 (GHSA-3m6g-2423-7cp3); lockfile pins json **2.19.5**.

### Dependencies

- **tty-table** — Bundled from `foxweb/tty-table` (`separator_bug` branch) so table separators render correctly.
- **Bundler** — `Gemfile.lock` refreshed (Bundler 4.0.11, checksums).

## [0.1.1] - 2026-04-21

### Added

- **Future payments: monthly subtotal row** — Added an intermediate monthly subtotal in `future_payments_table`. After the last payment in each month, the table now prints a subtotal for that month.

### Changed

- **Future payments: subtotal formatting** — Monthly subtotal amount is highlighted in bright green (`bold`) for better visual scanning.
- **Future payments: section spacing** — Added an empty separator row after each monthly subtotal row to visually split month sections.
- **Future payments: cleaner totals** — Zero-value chunks (`0.00`) are filtered out from monthly subtotal output.

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
