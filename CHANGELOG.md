# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.10.0] - 2026-10-13

The exact-parity release: every audited function — numeric series and
all 61 candlestick patterns — now matches the real TA-Lib C library
(TA-Lib 0.8.1 through its Python bindings) bar for bar on shared
fixtures. See `docs/BENCHMARKS.md` for the value audit.

### Changed (breaking)

- **CDL**: every pattern is retranslated from the TA-Lib C source with
  its candle-settings table — bodies judged against the average real
  body of the 10 previous candles, doji at 10% of the average high-low
  range, shadows against the body or average shadow sum, near/far/
  equal distances from the average high-low range of the 5 previous
  candles. The `average_period` parameter is gone from all 61 pattern
  functions (TA-Lib's settings are fixed, not per-call); the
  `penetration` parameters stay with TA-Lib's defaults. Scores change
  accordingly, and warmup bars inside each pattern's lookback now
  score `0` exactly like TA-Lib.
- **CDL hikkake/hikkake_mod**: `hikkake_mod` is the real 4-bar
  modified pattern (two inside bars, the second closing near its
  extreme), and both report `±200` when a close confirms the setup
  within three bars. `engulfing`/`harami`/`harami_cross` report `±80`
  when the touching bodies are merely equal.
- **MA**: DEMA, TEMA and T3 combine their EMA stages tail-aligned
  (the stages previously paired head-to-tail, skewing early values);
  T3 uses TA-Lib's exact coefficient arithmetic. KAMA now mirrors
  TA-Lib: fixed smoothing constants (fastest 2/3, slowest 2/31
  regardless of period), efficiency ratio clamped to 1 and set to 1
  on flat windows, sliding volatility sum, and a plain copy of the
  input at period 1. The KAMA walk is single-pass, ~9x faster at
  100k points.
- **MACD**: the line is seeded like TA-Lib (slow EMA from the average
  of the first `slow` prices, fast EMA from the average of the last
  `fast` of those) and `macd_ext/5` delegates its `:ema` variant
  through the same walk, so MACD, MACDFIX and MACDEXT agree with the
  C library bit for bit. Early MACD-line values change (they converge
  to the old ones after `2 * slow` bars).

### Added

- `bench/audit_dump.exs`: the value-audit fixture generator and dump
  (`mix run bench/audit_dump.exs <dir> [size] [seed]`), the Elixir
  half of the TA-Lib agreement check described in
  `docs/BENCHMARKS.md`.

## [0.9.1] - 2026-10-13

### Added

- `bench/bench.exs`: a dependency-free benchmark harness
  (`mix run bench/bench.exs [size]`), plus `docs/BENCHMARKS.md` with a
  TAlib-vs-TA-Lib(C) comparison table at 100k points (same-machine,
  same-VM Docker runs) and the numerical-agreement audit below.

### Fixed

- **CDL was quadratic**: the per-bar candle context re-sliced the
  bodies list from a growing offset (9.2 s per pattern on 100k bars).
  Both the average-body and the windowing are now single-pass — a
  ~400x speedup with identical scores.
- **`OBV` now seeds the line with the first bar's volume** and
  **`ATR` seeds on the close-based True Ranges of bars `1..period`**,
  emitting from bar `period` — both now match actual TA-Lib output
  exactly (OBV: 0.0 absolute difference; ATR: 4e-16 relative).
- `HT.ht_dcperiod`, `HT.ht_phasor` and `MAMA`/`FAMA` now use TA-Lib's
  12-bar warmup and emit from bar 32 (the 63-lookback family keeps
  37/63), verified against the real C library to 1e-13.

### Notes

- Value-level audit against the real TA-Lib C library (not a
  transliteration): SMA/EMA/WMA/RSI/BBands/StdDev/OBV/ATR and the full
  Hilbert/MESA family match within 1e-13; `MACD.macd/3` and `dema/2`
  differ in early values due to TA-Lib's unstable-period EMA seeding
  (documented in `docs/BENCHMARKS.md`); 39 of 61 candlestick patterns
  are bit-exact on the reference fixture.

## [0.9.0] - 2026-10-13

### Added

- **`TAlib.Indicators.HT`** — the full Hilbert-transform cycle family,
  translated from the TA-Lib C reference implementation of Ehlers' MESA
  machinery: `ht_trendline`, `ht_dcperiod`, `ht_dcphase`, `ht_phasor`
  (in-phase/quadrature), `ht_sine` (sine/lead-sine) and `ht_trendmode`.
- **`TAlib.Indicators.MAMA`** — the MESA Adaptive Moving Average with
  FAMA and TA-Lib-compatible fast/slow limit validation.

### Notes

- **133 of 133 TA-Lib functions covered — full parity.** Every HT/MAMA
  series was cross-verified against a transliteration of the same C
  source on trend and mixed-price fixtures (bit-for-bit identical
  output). The family warms up over a fixed 63-bar preamble and nils
  those entries; TA-Lib's configurable unstable-period handling is not
  mirrored (documented in `PARITY.md`).

## [0.8.0] - 2026-10-12

### Added

- **All 61 TA-Lib candlestick patterns** in `TAlib.Indicators.CDL`: per-bar
  scores (+100 bullish / -100 bearish / 0 none) over OHLC bars, following
  the canonical TA-Lib/StockCharts definitions with a configurable
  average-body window (default 5). Every pattern's output is
  cross-checked against an independent reference implementation on a
  mixed fixture. `hikkake`/`hikkake_mod` return base setups only;
  TA-Lib's confirmed ±200 levels are pending.
- `MA.ma/3`: generic moving-average dispatcher over eight types
  (`:sma`, `:ema`, `:wma`, `:dema`, `:tema`, `:trima`, `:kama`, `:t3`).
- `MA.mavp/5`: variable-period moving average (sma/ema, clamped periods).
- `MACD.macd_ext/5`: MACD with configurable MA types for the line and
  signal; `MACD.macd_fix/4`: signal EMA over the whole MACD series.
- `SAR.sar_ext/4`: extended Parabolic SAR.

### Notes

- `PARITY.md` now reports 126 of 133 TA-Lib functions; the remaining
  seven (HT_TRENDLINE, the five cycle indicators and MAMA) share the
  Hilbert-transform/MESA machinery and need a faithful translation from
  the TA-Lib C source.

## [0.7.0] - 2026-10-12

### Added

TA-Lib parity push: 24 new functions and a function-by-function coverage
map in `PARITY.md` (61 of 133 TA-Lib functions covered — everything
outside candlestick patterns, Hilbert-transform cycle indicators and the
MA-type-generic variants).

- Overlap: `MA.dema`, `MA.tema`, `MA.trima`, `MA.kama`, `MA.t3`,
  `MA.midpoint`, `Donchian.midprice`, and the `SAR` module (Parabolic SAR)
- Momentum: `APO`, `PPO`, `Aroon` (up/down/oscillator), `BOP`, `CMO`,
  `StochRSI`, `UltimateOsc`, `Stochastic.slow` (TA-Lib STOCH),
  `ADX.dx`, `ADX.adxr`, `ADX.plus_dm`, `ADX.minus_dm`,
  `ROC.rocp/rocr/rocr100`
- Volume: `ChaikinAD.ad/adosc`
- Volatility: `ATR.natr`, `ATR.true_range`
- Statistics: `Stats` — variance, beta, correl, linear regression
  (value/slope/intercept/angle), time series forecast
- Price transforms: `PriceTransform.avgprice/medprice/typprice/wclprice`

### Changed

- **Breaking:** `RSI` now uses Wilder's smoothing (RMA seeded with an SMA),
  matching TA-Lib; values differ from the previous Cutler-style averages.
  `average_gain/2` and `average_loss/2` return the Wilder-smoothed averages
  and `nil` (previously `0`) when there is not enough data.

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
