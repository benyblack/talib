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
| `MA.sma_list` (20) | 2.3 | 0.086 | 26x |
| `MA.ema_list` (20) | 3.2 | 0.139 | 23x |
| `MA.wma_list` (20) | 4.3 | 0.084 | 51x |
| `MA.dema_list` (20) | 19.2 | 0.148 | 130x |
| `MA.kama_list` (20) | 12.8 | 0.164 | 78x |
| `RSI.rsi_list` (14) | 29.1 | 0.219 | 133x |
| `MACD.macd_fix` (12/26/9) | 10.6 | 0.424 | 25x |
| `BBands.bbands_list` (20, 2) | 107.6 | 0.489 | 220x |
| `StdDev.std_dev_list` (20) | 12.9 | 0.166 | 77x |
| `ATR.atr_list` (14) | 11.2 | 0.079 | 141x |
| `OBV.obv_list` | 2.4 | 0.043 | 56x |
| `CDL.doji` | 103.7 | 0.089 | 1165x |
| `CDL.engulfing` | 107.7 | 0.042 | 2564x |
| `CDL.three_white_soldiers` | 119.9 | 0.519 | 231x |
| `HT.ht_trendline` | 554.9 | 3.343 | 166x |
| `HT.ht_dcphase` | 636.0 | 19.332 | 33x |
| `MAMA.mama` (0.5, 0.05) | 533.4 | 3.203 | 167x |

Takeaways:

- For the single-pass series functions (SMA/EMA/WMA/OBV/StdDev/ATR),
  TAlib lands at 20-80x the C library — the cost of immutable-list
  walking versus mutable arrays, roughly 2-5 us per bar.
- KAMA became a single-pass sliding walk (0.10.0), an ~9x speedup over
  the per-bar window recomputation. The Hilbert family pays for the
  per-bar map the shared core emits (the C code updates scalars in
  place), and the candlestick patterns pay for the four trailing sums
  plus windowed scoring that TA-Lib's exact thresholds need.
- Everything is linear in the input; nothing is quadratic. (It was not
  always so: the original `CDL` context builder re-sliced per bar —
  9.2 s per pattern at 100k. It was fixed to a single-pass sliding
  average in 0.9.1, a ~400x speedup, caught by exactly this harness.)
- At typical interactive sizes (hundreds to a few thousand bars), every
  function returns in single-digit milliseconds.

## Numerical agreement with TA-Lib

Beyond timing, the same Docker setup verifies values against the real
C library (not just a transliteration): `bench/audit_dump.exs` dumps
every function's output on shared fixtures (a smooth series plus
pseudo-random OHLC bars), and a small numpy/talib script compares bar
by bar. As of 0.10.0, verified on four fixtures (500-800 bars, four
seeds):

- **Bit-exact (max rel err 0)**: SMA, EMA, DEMA, TEMA, T3, OBV, the
  MACD line and `macd_fix` (all three outputs), and `ht_trendline`.
- **Bit-near (max rel err <= 1e-12)**: WMA (1.5e-14), KAMA (1.6e-16),
  RSI (7e-14), Bollinger (1.9e-14), StdDev (4.3e-12), ATR (5.2e-16),
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
