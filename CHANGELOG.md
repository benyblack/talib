# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.0] - 2026-10-12

### Added

Thirteen new indicators, all following the library conventions (chronological
input, nil-padded series, `nil` — never `0` — for insufficient data, positive
integer periods). Bar-based indicators take maps (`%{high: , low: , close: }`
plus `%{volume: }` where needed); extra keys are ignored.

- `MA.rma/2` and `MA.rma_list/2`: Wilder's smoothed average, the shared
  building block for ATR and ADX
- `StdDev`: rolling population standard deviation (`std_dev/2`, `std_dev_list/2`)
- `BBands`: Bollinger Bands (`bbands/3`, `bbands_list/3`)
- `ROC`: rate of change (`roc/2`, `roc_list/2`)
- `Momentum`: momentum (`momentum/2`, `momentum_list/2`)
- `WilliamsR`: Williams %R (`williams_r/2`, `williams_r_list/2`)
- `TRIX`: triple-smoothed EMA rate of change (`trix/2`, `trix_list/2`)
- `ATR`: Average True Range, Wilder-smoothed (`atr/2`, `atr_list/2`)
- `Keltner`: Keltner Channels, EMA ± mult·ATR (`keltner/3`, `keltner_list/3`)
- `Donchian`: Donchian Channels (`donchian/2`, `donchian_list/2`)
- `ADX`: directional movement — `plus_di/2`, `minus_di/2`, `adx/2` and the
  one-pass `adx_all/2` map, with per-value `nil`s while data accumulates
- `CCI`: Commodity Channel Index (`cci/2`, `cci_list/2`)
- `OBV`: On-Balance Volume (`obv/1`, `obv_list/1`)
- `MFI`: Money Flow Index (`mfi/2`, `mfi_list/2`)
- `VWAP`: rolling volume-weighted average price (`vwap/2`, `vwap_list/2`) —
  the windowed variant, not the session-anchored one

### Notes

- Expected values for the new indicators were cross-verified against an
  independent reference implementation; the ATR/ADX smoothing follows the
  standard TA-Lib convention (RMA seeded with an SMA).

## [0.5.0] - 2026-10-12

### Changed

- **Breaking:** every function now takes prices in **chronological order,
  oldest price first**. Previously the scalar functions (`sma/2`, `ema/2`,
  `wma/2`, `rsi/2`, `macd/3`, `stochastic_k/2`, the `update_*` helpers and
  friends) expected the newest price first while the `*_list` functions
  expected oldest first — two contradictory conventions in one library.
  Pass your series the way you store it; series-function results are
  unchanged.
- **Breaking:** `RSI.rsi_list/2` no longer takes the `top_is_first` flag
  (meaningless under a single convention); `rsi_list(data, period, true)`
  becomes `rsi_list(data, period)`.
- All series functions are now single-pass O(n) implementations: sliding
  window sums for SMA/WMA/RSI and one forward EMA walk for the EMA series.
  The MACD line, signal and histogram share a single fast/slow EMA pass.
  Values match earlier releases up to floating-point rounding introduced
  by the sliding arithmetic.

### Added

- `MA.wma_list/2` and `MA.cma_list/1`, giving the series functions parity
  with the scalars.
- `MACD.macd_list/3` (full MACD line series) and `MACD.macd_all/4`, which
  returns `%{macd:, signal:, histogram:}` for the latest point computed in
  a single pass, with per-value `nil`s while data accumulates.
- `Stochastic.stochastic_k_list/2` (full %K series; %D is derived from it).

## [0.4.0] - 2026-10-10

### Added

- `MACD.signal/4` accepts the fast and slow MACD periods (`signal(prices, period, fast, slow)`).
- Lookback periods are now validated: anything other than a positive integer raises `ArgumentError`.
- Doctests for all public functions; several documentation examples were plain wrong and are now executable and verified.
- Project infrastructure: MIT `LICENSE`, this changelog, and CI (GitHub Actions) running format checks and the test suite on an Elixir/OTP matrix.
- `mix.exs` now sets `source_url` and ex_doc configuration so published docs link back to source.

### Fixed

- **WMA applied its weights in reverse**: the documented convention is newest price first, but the oldest price in the window received the highest weight (the opposite of TA-Lib/pandas). The newest price now gets weight `period`, descending to 1 for the oldest price in the window.
- **`MA.update_sma/4` dropped the wrong price from the window** (it read the element at index `period + 1` instead of `period - 1`). Its only test passed by numerical accident (`new_value` happened to equal the subtracted element, so both terms cancelled); it now verifies against recomputing the window.
- **`MACD.signal/2` ignored its `period` argument** — the EMA over the MACD series was hardcoded to 9. It also silently averaged zeros into that EMA when the price list was too short for every MACD value to be defined (the guard only required `period * 2 - 1` prices, while each MACD needs `slow * 2`); it now returns `nil` unless `slow * 2 + period * 2 - 1` prices are available.
- **`MACD.macd/3` crashed when the fast period exceeded the available data** (the guard only checked the slow period; the fast EMA then returned `nil` and the subtraction raised). Both periods are now checked.
- **`RSI.average_gain/2` and `RSI.average_loss/2` raised `ArithmeticError` on single-element lists** (division by `length - 1 = 0`). They now return `0.0`.
- **`RSI.rsi_list/3` crashed on empty input** (`tl([])`), and `MA.sma_list/2` / `MA.ema_list/2` returned `[nil]` instead of `[]` for empty input.
- **`Stochastic.stochastic_k/2` raised on zero-range windows** (flat prices → division by zero). It returns `nil` when the window has no range, since `%K` is then undefined.

### Changed

- **Breaking:** "not enough data" now consistently returns `nil`. Previously `MACD` and `Stochastic` returned `0` — a perfectly legitimate indicator reading (extreme oversold) that could generate phantom trading signals.
- **Breaking:** `MA.cma/1` is now the true cumulative (unweighted) mean of all given prices. Previously it took a `period` and was just a duplicate of `sma/2` with a stricter guard, which was inconsistent with `update_cma/3`.
- **Breaking:** `MA.update_sma/4` now expects `prices` to *not* include the new value: the value leaving the window is `Enum.at(prices, period - 1)`, and it returns `nil` (previously `0`) when fewer than `period` prices are given.
- **Breaking:** `Stochastic.stochastic_d/3` signature is now `(prices, period, d_period)`, where `period` is the `%K` lookback (default 14) and `d_period` the SMA applied to `%K` (default 3). Previously `period` was the SMA length but was effectively ignored — the SMA was hardcoded to 3.
- **Breaking:** `RSI.rsi/2` returns `nil` (previously `0`) for empty input, and `nil` for windows with no price movement, where RSI is mathematically undefined.
- `MA.sma_list/2` and `MA.ema_list/2` build their result in a single pass instead of repeatedly appending to the accumulated list.

## [0.3.6] - 2019-07-15

- Add `MA.ema_list/2`; fix MACD test expectations against reference (`py_talib`) results.

## [0.3.4] – [0.3.5] - 2019-07-05

- Add `RSI.rsi_list/3` and `MA.sma_list/2`.

## [0.3.0] – [0.3.3] - 2019-04-01

- Add incremental update helpers (`update_sma/4`, `update_cma/3`, `update_ema/3`), fix RSI/RS calculation and SMA windowing.

## [0.1.0] – [0.2.0] - 2019-03-28

- Initial public releases: SMA/EMA/CMA/WMA, RSI, MACD, Stochastic.

(Entries before 0.4.0 are summarized from git history; this changelog was not maintained at the time.)
