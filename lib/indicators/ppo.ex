defmodule TAlib.Indicators.PPO do
  alias TAlib.Indicators.MA

  @moduledoc """
  Percentage Price Oscillator: `(EMA(fast) - EMA(slow)) / EMA(slow) * 100`.

  See `TAlib` for the conventions: prices are always given in
  chronological order, oldest first, and the series is returned aligned
  with the input. `nil` is returned when there is not enough data. For
  the absolute variant see `TAlib.Indicators.APO`.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate the latest Percentage Price Oscillator value, in percent.

  ## Parameters

    - prices: list of prices, oldest first.
    - fast: fast EMA period, a positive integer (default 12).
    - slow: slow EMA period, a positive integer (default 26).

  ## Examples

      iex> TAlib.Indicators.PPO.ppo([1, 2, 3, 4, 5, 6, 7, 8], 2, 4) |> Float.round(4)
      15.3846
  """
  @spec ppo(list(number), pos_integer, pos_integer) :: float | nil
  def ppo(prices, fast \\ 12, slow \\ 26)

  def ppo(_prices, fast, _slow) when not is_valid_period(fast), do: TAlib.invalid_period!(fast)

  def ppo(_prices, _fast, slow) when not is_valid_period(slow), do: TAlib.invalid_period!(slow)

  def ppo(prices, _fast, slow) when is_list(prices) and length(prices) < slow, do: nil

  def ppo(prices, fast, slow) when is_list(prices) do
    slow_ema = MA.ema(prices, slow)

    if slow_ema == 0,
      do: nil,
      else: (MA.ema(prices, fast) - slow_ema) / slow_ema * 100
  end

  @doc """
  Calculate the full PPO series, defined once the slow EMA exists
  (index `slow - 1` on).

  ## Parameters

    - prices: list of prices, oldest first.
    - fast: fast EMA period, a positive integer (default 12).
    - slow: slow EMA period, a positive integer (default 26).

  ## Examples

      iex> TAlib.Indicators.PPO.ppo_list([1, 2, 3, 4, 5, 6, 7, 8], 2, 4) |> Enum.map(fn
      ...>   nil -> nil
      ...>   x -> Float.round(x, 4)
      ...> end)
      [nil, nil, nil, 40.0, 28.5714, 22.2222, 18.1818, 15.3846]
  """
  @spec ppo_list(list(number), pos_integer, pos_integer) :: list(float | nil)
  def ppo_list(prices, fast \\ 12, slow \\ 26)

  def ppo_list(_prices, fast, _slow) when not is_valid_period(fast),
    do: TAlib.invalid_period!(fast)

  def ppo_list(_prices, _fast, slow) when not is_valid_period(slow),
    do: TAlib.invalid_period!(slow)

  def ppo_list(prices, fast, slow) when is_list(prices) do
    fast_series = MA.ema_list(prices, fast)
    slow_series = MA.ema_list(prices, slow)

    fast_series
    |> Enum.zip(slow_series)
    |> Enum.map(fn
      {nil, _} -> nil
      {_, nil} -> nil
      {_, 0} -> nil
      {f, s} -> (f - s) / s * 100
    end)
  end
end
