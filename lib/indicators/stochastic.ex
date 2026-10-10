defmodule TAlib.Indicators.Stochastic do
  alias TAlib.Indicators.MA

  @moduledoc """
  Stochastic oscillator [Wikipedia](https://en.wikipedia.org/wiki/Stochastic_oscillator).

  * `%K = (Close - Lowest Low) / (Highest High - Lowest Low) * 100`
  * `%D = SMA(%K, d_period)`

  See `TAlib` for the input conventions: prices are given newest first.
  `nil` is returned when there is not enough data or the window has no
  range (flat prices), since `%K` is then undefined.

  Note that with a plain price list, close, high and low all come from the
  same series; for proper high/low support an OHLC input shape is needed.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  %K = (Current Close - Lowest Low) / (Highest High - Lowest Low) * 100

  ## Parameters

    - prices: list of prices, newest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.Stochastic.stochastic_k([3, 2, 5, 1, 4], 5)
      50.0

      iex> TAlib.Indicators.Stochastic.stochastic_k([5, 5, 5], 3)
      nil
  """
  @spec stochastic_k(list(number), pos_integer) :: float | nil
  def stochastic_k(prices, period \\ 14)

  def stochastic_k(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def stochastic_k(prices, period) when is_list(prices) and length(prices) < period, do: nil

  def stochastic_k(prices, period) when is_list(prices) do
    price_history = Enum.take(prices, period)
    lowest_low = Enum.min(price_history)
    highest_high = Enum.max(price_history)
    range = highest_high - lowest_low

    if range == 0 do
      nil
    else
      (hd(price_history) - lowest_low) / range * 100
    end
  end

  @doc """
  %D: the `d_period`-period simple moving average of %K.

  ## Parameters

    - prices: list of prices, newest first.
    - period: %K lookback window, a positive integer (default 14).
    - d_period: SMA period applied to %K, a positive integer (default 3).

  ## Examples

      iex> TAlib.Indicators.Stochastic.stochastic_d([4, 7, 3, 5, 2, 6, 1], 5, 3)
      60.0
  """
  @spec stochastic_d(list(number), pos_integer, pos_integer) :: float | nil
  def stochastic_d(prices, period \\ 14, d_period \\ 3)

  def stochastic_d(_prices, period, _d_period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def stochastic_d(_prices, _period, d_period) when not is_valid_period(d_period),
    do: TAlib.invalid_period!(d_period)

  def stochastic_d(prices, period, d_period)
      when is_list(prices) and length(prices) < period + d_period - 1,
      do: nil

  def stochastic_d(prices, period, d_period) when is_list(prices) do
    k_list =
      Enum.map(0..(d_period - 1), fn x ->
        stochastic_k(Enum.slice(prices, x, period), period)
      end)

    if Enum.any?(k_list, &is_nil/1) do
      nil
    else
      MA.sma(k_list, d_period)
    end
  end
end
