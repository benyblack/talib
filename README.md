# TAlib

Technical analysis library for Elixir.

## Indicators

All 133 [TA-Lib](https://github.com/ta-lib/ta-lib-python) functions are covered —
see [PARITY.md](PARITY.md) for the function-by-function map. The Hilbert-transform
family and MAMA are faithful translations of the TA-Lib C reference,
cross-verified series for series.

- Overlap studies: SMA, EMA, WMA, CMA, Wilder RMA, DEMA, TEMA, TRIMA, KAMA,
  T3, Midpoint, Midprice, Bollinger Bands, Keltner Channels, Donchian
  Channels, Parabolic SAR — scalars and full series, plus incremental
  `update_*` variants for streaming updates
- Momentum: RSI (Wilder), MACD, Stochastic (fast and slow), Stochastic RSI,
  Williams %R, ROC/ROCP/ROCR/ROCR100, Momentum, TRIX, CMO, APO, PPO, Aroon,
  Aroon Oscillator, BOP, CCI, ADX/DMI (+DI, -DI, DX, ADXR)
- Volatility: StdDev, Variance, ATR, NATR, True Range
- Volume: OBV, MFI, rolling VWAP, Chaikin A/D line and oscillator
- Statistics: linear regression (value/slope/intercept/angle), Time Series
  Forecast, Beta, Correlation
- Candlestick patterns: all 61 TA-Lib CDL functions via `TAlib.Indicators.CDL`,
  scored per bar (+100 bullish / -100 bearish / 0 none)
- Generic moving-average dispatch (`MA.ma/3`), variable-period MA (`mavp`),
  `MACD.macd_ext/macd_fix`, extended Parabolic SAR
- Cycle indicators: the full Hilbert-transform family (`HT.ht_trendline`,
  `ht_dcperiod`, `ht_dcphase`, `ht_phasor`, `ht_sine`, `ht_trendmode`) and
  `MAMA.mama` (with FAMA)

Bar-based indicators take maps such as
`%{open: o, high: h, low: l, close: c, volume: v}` with the keys they need —
extra keys are ignored.

## Installation

The package can be installed by adding `talib` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:talib, "~> 0.7"}
  ]
end
```

## Conventions

- Prices are always given in **chronological order, oldest price first**.
  Series functions return results aligned with the input list, `nil`-padded
  while the lookback window fills up; scalar functions return the value at
  the latest point.
- Lookback periods must be positive integers; anything else raises `ArgumentError`.
- Every function returns `nil` — never `0` — when there is not enough data,
  since `0` is a legitimate reading for several indicators.

## Examples

```elixir
iex> TAlib.Indicators.MA.sma([1330.95, 1334.65, 1340.0], 3)
1335.2

iex> TAlib.Indicators.MA.sma_list([1, 2, 3, 4, 5], 3)
[nil, nil, 2.0, 3.0, 4.0]

iex> TAlib.Indicators.RSI.rsi([6, 1, 4, 2, 5, 3], 3) |> Float.round(4)
42.8571

iex> TAlib.Indicators.MACD.macd_all(prices)
%{macd: 20.36, signal: 12.28, histogram: 8.08}
```

More examples can be found in the module documentation
([Hexdocs](https://hexdocs.pm/talib/)) and in the test suite.
