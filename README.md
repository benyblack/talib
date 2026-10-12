# TAlib

Technical analysis library for Elixir.

## Indicators

- Moving averages: SMA, EMA, WMA, CMA and Wilder's RMA — as scalars, as full
  series, plus incremental `update_*` variants for streaming updates
- Momentum: RSI, MACD (line/signal/histogram), ROC, Momentum, TRIX, Stochastic
  oscillator (%K, %D), Williams %R, CCI, ADX/DMI (+DI, -DI, ADX)
- Volatility: StdDev, Bollinger Bands, ATR, Keltner Channels, Donchian Channels
- Volume: OBV, MFI, rolling VWAP

Bar-based indicators (ATR, ADX, CCI, Keltner, Donchian, MFI, OBV, VWAP) take
maps such as `%{high: h, low: l, close: c, volume: v}` — extra keys are ignored.

## Installation

The package can be installed by adding `talib` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:talib, "~> 0.6"}
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
