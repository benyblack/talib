# TAlib

Technical analysis library for Elixir.

## Indicators

- Moving averages: SMA, EMA, WMA and CMA — plus incremental `update_*` variants for streaming updates
- RSI
- MACD: line, signal and histogram
- Stochastic oscillator: %K and %D

## Installation

The package can be installed by adding `talib` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:talib, "~> 0.4"}
  ]
end
```

## Conventions

- **Scalar functions** (`TAlib.Indicators.MA.sma/2`, `TAlib.Indicators.RSI.rsi/2`,
  `TAlib.Indicators.MACD.macd/3`, `TAlib.Indicators.Stochastic.stochastic_k/2`, ...)
  take prices with the **newest price first**.
- **Series functions** (`TAlib.Indicators.MA.sma_list/2`, `TAlib.Indicators.MA.ema_list/2`,
  `TAlib.Indicators.RSI.rsi_list/3`) take prices in **chronological order, oldest first**,
  and return a series aligned with the input.
- Lookback periods must be positive integers; anything else raises `ArgumentError`.
- Every function returns `nil` — never `0` — when there is not enough data,
  since `0` is a legitimate reading for several indicators.

## Examples

```elixir
iex> TAlib.Indicators.MA.sma([1330.95, 1334.65, 1340.0], 3)
1335.2

iex> TAlib.Indicators.MA.sma_list([1, 2, 3, 4, 5], 3)
[nil, nil, 2.0, 3.0, 4.0]

iex> TAlib.Indicators.RSI.rsi([3, 5, 2, 4, 1, 6], 3) |> Float.round(4)
42.8571
```

More examples can be found in the module documentation
([Hexdocs](https://hexdocs.pm/talib/)) and in the test suite.
