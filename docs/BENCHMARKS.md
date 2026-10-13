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
| `MA.sma_list` (20) | 2.0 | 0.086 | 24x |
| `MA.ema_list` (20) | 4.6 | 0.139 | 33x |
| `MA.wma_list` (20) | 5.3 | 0.084 | 63x |
| `MA.dema_list` (20) | 17.8 | 0.148 | 120x |
| `MA.kama_list` (20) | 119.0 | 0.164 | 726x |
| `RSI.rsi_list` (14) | 26.2 | 0.219 | 119x |
| `MACD.macd_fix` (12/26/9) | 20.9 | 0.424 | 49x |
| `BBands.bbands_list` (20, 2) | 102.5 | 0.489 | 210x |
| `StdDev.std_dev_list` (20) | 7.3 | 0.166 | 44x |
| `ATR.atr_list` (14) | 6.5 | 0.079 | 82x |
| `OBV.obv_list` | 2.6 | 0.043 | 60x |
| `CDL.doji` | 22.8 | 0.089 | 256x |
| `CDL.engulfing` | 40.7 | 0.042 | 970x |
| `CDL.three_white_soldiers` | 43.2 | 0.519 | 83x |
| `HT.ht_trendline` | 853.5 | 3.343 | 255x |
| `HT.ht_dcphase` | 635.2 | 19.332 | 33x |
| `MAMA.mama` (0.5, 0.05) | 540.9 | 3.203 | 169x |

Takeaways:

- For the single-pass series functions (SMA/EMA/WMA/OBV/StdDev/ATR),
  TAlib lands at 20-80x the C library — the cost of immutable-list
  walking versus mutable arrays, roughly 2-5 us per bar.
- Windowed functions (BBands) and stateful walks (KAMA) pay an extra
  per-bar window cost; the Hilbert family pays for the per-bar map the
  shared core emits (the C code updates scalars in place).
- Everything is linear in the input; nothing is quadratic. (It was not
  always so: the original `CDL` context builder re-sliced per bar —
  9.2 s per pattern at 100k. It was fixed to a single-pass sliding
  average in 0.9.1, a ~400x speedup, caught by exactly this harness.)
- At typical interactive sizes (hundreds to a few thousand bars), every
  function returns in single-digit milliseconds.

## Numerical agreement with TA-Lib

Beyond timing, the same Docker setup verifies values against the real
C library (not just a transliteration) on a ramp and the mixed price
fixture. As of 0.9.1:

- **Bit-near exact (max rel err <= 1e-13)**: SMA, EMA, WMA, RSI,
  Bollinger upper, StdDev, OBV (exact), ATR (4e-16), and the whole
  Hilbert/MESA family — `ht_trendline`, `ht_dcperiod`, `ht_dcphase`,
  `ht_sine`, `ht_phasor`, `MAMA`, `FAMA` (which additionally start at
  TA-Lib's own bar 32/63 offsets, unstable period 0).
- **Known divergences** (documented, deliberate or structural):
  - `MACD.macd/3` and `dema/2`: TA-Lib seeds the inner EMAs through
    its unstable-period machinery, shifting early values; our seeds
    are the plain SMA-on-first-window. `macd_fix/4` follows the
    documented MACDFIX seeding.
  - `kama/2`: efficiency-ratio accumulation order differs in the
    extremes (~1e-3 drift on synthetic data).
  - Candlestick patterns: 39 of 61 are bit-exact on the reference
    fixture; the rest differ on edge thresholds (our canonical
    definitions versus TA-Lib's tuned constants).

## Reproducing

```sh
mix run bench/bench.exs 100000
```

For the TA-Lib side, any environment with the `ta-lib` Python bindings
and numpy can run the mirrored script over the same data formula (see
`bench/bench.exs` for the generation rule).
