# Benchmarks

TAlib (pure Elixir) versus TA-Lib (the C library through its Python
bindings, `ta-lib` 0.8.2), on identical deterministic data.

## Method

Both sides ran in Docker on the same Linux VM of the same machine
(`elixir:1.17-slim` / `python:3.12-slim`), on 100,000 data points,
median of repeated runs after warmup. The harnesses are committed:
`bench/bench.exs` (dependency-free; `mix run bench/bench.exs [size]`)
and the equivalent Python script driving the `talib` bindings over
numpy arrays. Bars (for the OHLC functions) derive from the same price
series by a fixed formula on both sides.

The comparison is a ballpark, not a controlled benchmark: TA-Lib
computes over contiguous mutable arrays in hand-tuned C, while TAlib
walks immutable linked lists and allocates its output per element. The
column to watch is the order of magnitude.

## Results (100k points, median ms)

| Function | TAlib (Elixir) | TA-Lib (C) | Ratio |
| --- | ---: | ---: | ---: |
| `MA.sma_list` (20) | 1.9 | 0.078 | 25x |
| `MA.ema_list` (20) | 3.7 | 0.137 | 27x |
| `MA.wma_list` (20) | 5.0 | 0.080 | 63x |
| `MA.dema_list` (20) | 14.8 | 0.148 | 100x |
| `MA.kama_list` (20) | 13.2 | 0.137 | 97x |
| `MA.midpoint_list` (20) | 25.6 | 0.116 | 220x |
| `RSI.rsi_list` (14) | 16.3 | 0.200 | 82x |
| `MACD.macd_fix` (12/26/9) | 12.2 | 0.462 | 27x |
| `BBands.bbands_list` (20, 2) | 14.2 | 0.500 | 28x |
| `StdDev.std_dev_list` (20) | 7.2 | 0.162 | 45x |
| `ATR.atr_list` (14) | 8.0 | 0.079 | 101x |
| `OBV.obv_list` | 1.4 | 0.044 | 33x |
| `Stochastic.slow` (14, 3, 3) | 36.1 | 1.037 | 35x |
| `WilliamsR.williams_r_list` (14) | 28.5 | 0.175 | 163x |
| `Aroon.aroon_list` (14) | 26.0 | 0.571 | 46x |
| `CCI.cci_list` (20) | 32.0 | 1.459 | 22x |
| `StochRSI.stoch_rsi_list` (14, 5) | 45.4 | 0.738 | 62x |
| `CDL.doji` | 98.9 | 0.101 | 984x |
| `CDL.engulfing` | 105.4 | 0.041 | 2547x |
| `CDL.three_white_soldiers` | 87.0 | 0.559 | 156x |
| `HT.ht_trendline` | 598.5 | 3.338 | 179x |
| `HT.ht_dcphase` | 653.6 | 19.389 | 34x |
| `MAMA.mama` (0.5, 0.05) | 555.4 | 3.215 | 173x |

(`Donchian.donchian_list` (20) runs at 53.1 ms; TA-Lib has no Donchian
function to compare against.)


- The single-pass series functions (SMA/EMA/WMA/OBV/StdDev/ATR/RSI)
  land at 25-100x the C library — the cost of immutable-list walking
  versus mutable arrays.
- The windowed family became single-pass in 0.11.0: Bollinger Bands
  ride sliding sums (11x faster, 226x -> 28x), Aroon/%R/stochastic/
  midpoint use monotonic deques for their rolling extremes, and CCI
  indexes its mean-deviation walk instead of allocating windows —
  every one still bar-for-bar identical to TA-Lib (see below).
- Scanning every candlestick pattern through `CDL.scan/2` shares one
  candle context across all 61 patterns: ~1.75 s at 100k bars versus
  ~6.8 s calling the patterns one by one (~3.9x). A single pattern
  costs the same either way.
- The Hilbert family still pays for the per-bar map its shared core
  emits (the C code updates scalars in place) — the remaining
  outlier at ~170x.
- Everything is linear in the input; nothing is quadratic. (It was
  not always so: the original `CDL` context builder re-sliced per bar —
  9.2 s per pattern at 100k — until the 0.9.1 single-pass rewrite.)
  At typical interactive sizes (hundreds to a few thousand bars), every
  function returns in single-digit milliseconds.

## Numerical agreement with TA-Lib

Beyond timing, the same Docker setup verifies values against the real
C library (not just a transliteration): `bench/audit_dump.exs` dumps
every function's output on shared fixtures (a smooth series plus
pseudo-random OHLC bars), and a small numpy/talib script compares bar
by bar. As of 0.11.0, verified on five fixtures (500-800 bars) and
covering the windowed family too:

- **Bit-exact (max rel err 0)**: SMA, EMA, DEMA, TEMA, T3, OBV, the
  MACD line and `macd_fix` (all three outputs), and `ht_trendline`.
- **Bit-near (max rel err <= 1e-12)**: WMA (1.5e-14), KAMA (1.6e-16),
  RSI (7e-14), Bollinger upper/middle/lower (1.3e-13), StdDev
  (4.3e-12), ATR (5.2e-16), fast %K and Williams %R (exact), Midpoint
  (exact), Aroon Up/Down (1.7e-16), StochRSI (2.1e-13), CCI (2.6e-12),
  `ht_dcperiod`/`ht_dcphase`/`ht_sine`/`ht_phasor`, MAMA/FAMA (6e-16)
  — all starting at TA-Lib's own bar offsets, unstable period 0.
- **All 61 candlestick patterns are integer-exact** bar for bar,
  including hikkake's `±200` confirmation levels and the `±80`
  equal-touch levels of engulfing/harami.

The one remaining documented difference is alignment, not values: our
`macd_list` defines the MACD line from bar `slow - 1` on (as soon as
both EMAs exist), while TA-Lib's MACD output begins at
`slow + signal - 2` because its lookback includes the signal warmup —
8 extra leading values on our side, identical thereafter.

## Reproducing

```sh
mix run bench/bench.exs 100000
mix run bench/audit_dump.exs /tmp 500 42
```

The second command writes the fixtures and a dump of every TAlib
output; any environment with the `ta-lib` Python bindings and numpy
compares them against the C library over the same files (see the
method description above).
