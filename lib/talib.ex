defmodule TAlib do
  @moduledoc """
  Technical analysis library for Elixir.

  ## Conventions

  * Prices are always given in **chronological order, oldest price first**.
    Series functions (`TAlib.Indicators.MA.sma_list/2`, `TAlib.Indicators.RSI.rsi_list/2`,
    ...) return results aligned with the input list, `nil`-padded while the
    lookback window fills up; scalar functions return the value at the
    latest point.
  * Bar-based indicators (`TAlib.Indicators.ATR`, `TAlib.Indicators.ADX`,
    `TAlib.Indicators.CCI`, `TAlib.Indicators.Keltner`, `TAlib.Indicators.Donchian`,
    `TAlib.Indicators.MFI`, `TAlib.Indicators.OBV`, `TAlib.Indicators.VWAP`)
    take maps with the keys they need — `%{high: , low: , close: }` plus
    `%{volume: }` for volume-based ones; extra keys are ignored.
  * Lookback periods must be positive integers; any other value raises
    `ArgumentError`.
  * Functions return `nil` — never `0` — when there is not enough data,
    since `0` is a legitimate reading for several indicators.
  """

  @doc false
  def invalid_period!(period) do
    raise ArgumentError, "period must be a positive integer, got: #{inspect(period)}"
  end
end
