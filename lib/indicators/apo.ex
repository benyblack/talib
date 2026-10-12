defmodule TAlib.Indicators.APO do
  alias TAlib.Indicators.MA

  @moduledoc """
  Absolute Price Oscillator: `EMA(fast) - EMA(slow)`.

  See `TAlib` for the conventions: prices are always given in
  chronological order, oldest first, and the series is returned aligned
  with the input. `nil` is returned when there is not enough data. For
  the percentage variant see `TAlib.Indicators.PPO`.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate the latest Absolute Price Oscillator value.

  ## Parameters

    - prices: list of prices, oldest first.
    - fast: fast EMA period, a positive integer (default 12).
    - slow: slow EMA period, a positive integer (default 26).

  ## Examples

      iex> TAlib.Indicators.APO.apo([1, 2, 3, 4, 5, 6, 7, 8], 2, 4)
      1.0
  """
  @spec apo(list(number), pos_integer, pos_integer) :: float | nil
  def apo(prices, fast \\ 12, slow \\ 26)

  def apo(_prices, fast, _slow) when not is_valid_period(fast), do: TAlib.invalid_period!(fast)

  def apo(_prices, _fast, slow) when not is_valid_period(slow), do: TAlib.invalid_period!(slow)

  def apo(prices, _fast, slow) when is_list(prices) and length(prices) < slow, do: nil

  def apo(prices, fast, slow) when is_list(prices),
    do: MA.ema(prices, fast) - MA.ema(prices, slow)

  @doc """
  Calculate the full APO series, defined once the slow EMA exists
  (index `slow - 1` on).

  ## Parameters

    - prices: list of prices, oldest first.
    - fast: fast EMA period, a positive integer (default 12).
    - slow: slow EMA period, a positive integer (default 26).

  ## Examples

      iex> TAlib.Indicators.APO.apo_list([1, 2, 3, 4, 5, 6, 7, 8], 2, 4)
      [nil, nil, nil, 1.0, 1.0, 1.0, 1.0, 1.0]
  """
  @spec apo_list(list(number), pos_integer, pos_integer) :: list(float | nil)
  def apo_list(prices, fast \\ 12, slow \\ 26)

  def apo_list(_prices, fast, _slow) when not is_valid_period(fast),
    do: TAlib.invalid_period!(fast)

  def apo_list(_prices, _fast, slow) when not is_valid_period(slow),
    do: TAlib.invalid_period!(slow)

  def apo_list(prices, fast, slow) when is_list(prices) do
    fast_series = MA.ema_list(prices, fast)
    slow_series = MA.ema_list(prices, slow)

    fast_series
    |> Enum.zip(slow_series)
    |> Enum.map(fn
      {nil, _} -> nil
      {_, nil} -> nil
      {f, s} -> f - s
    end)
  end
end
