defmodule TAlib do
  @moduledoc """
  Technical analysis library for Elixir.

  ## Conventions

  * Scalar indicator functions (`TAlib.Indicators.MA.sma/2`,
    `TAlib.Indicators.RSI.rsi/2`, `TAlib.Indicators.MACD.macd/3`,
    `TAlib.Indicators.Stochastic.stochastic_k/2`, ...) expect prices with
    the **newest price first**.
  * Series functions (`TAlib.Indicators.MA.sma_list/2`,
    `TAlib.Indicators.MA.ema_list/2`, `TAlib.Indicators.RSI.rsi_list/3`)
    expect prices in **chronological order, oldest price first** and return
    a series aligned with the input list.
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
