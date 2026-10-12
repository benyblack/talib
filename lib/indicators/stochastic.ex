defmodule TAlib.Indicators.Stochastic do
  alias TAlib.Indicators.MA

  @moduledoc """
  Stochastic oscillator [Wikipedia](https://en.wikipedia.org/wiki/Stochastic_oscillator).

  * `%K = (Close - Lowest Low) / (Highest High - Lowest Low) * 100`
  * `%D = SMA(%K, d_period)`

  See `TAlib` for the input conventions: prices are always given in
  chronological order, oldest first, and series are returned aligned with
  the input. `nil` is returned when there is not enough data or the window
  has no range (flat prices), since `%K` is then undefined.

  Note that with a plain price list, close, high and low all come from the
  same series; for proper high/low support an OHLC input shape is needed.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  %K = (Current Close - Lowest Low) / (Highest High - Lowest Low) * 100

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.Stochastic.stochastic_k([1, 2, 5, 1, 4], 5)
      75.0

      iex> TAlib.Indicators.Stochastic.stochastic_k([5, 5, 5], 3)
      nil
  """
  @spec stochastic_k(list(number), pos_integer) :: float | nil
  def stochastic_k(prices, period \\ 14)

  def stochastic_k(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def stochastic_k(prices, period) when is_list(prices) and length(prices) < period, do: nil

  def stochastic_k(prices, period) when is_list(prices),
    do: prices |> Enum.take(-period) |> k_over_window()

  @doc """
  Calculate the full %K series.

  Returns a list aligned with `prices`: the first `period - 1` entries are
  `nil`, and every later entry is %K of the window ending at that point.
  Windows with no range (flat prices) produce `nil`, since %K is then
  undefined.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.Stochastic.stochastic_k_list([1, 6, 2, 5, 3], 3)
      [nil, nil, 20.0, 75.0, 33.33333333333333]
  """
  @spec stochastic_k_list(list(number), pos_integer) :: list(float | nil)
  def stochastic_k_list(prices, period \\ 14)

  def stochastic_k_list(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def stochastic_k_list(prices, period) when is_list(prices) and length(prices) < period,
    do: List.duplicate(nil, length(prices))

  def stochastic_k_list(prices, period) when is_list(prices) do
    k_values = prices |> Enum.chunk_every(period, 1, :discard) |> Enum.map(&k_over_window/1)
    List.duplicate(nil, period - 1) ++ k_values
  end

  @doc """
  %D: the `d_period`-period simple moving average of %K.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: %K lookback window, a positive integer (default 14).
    - d_period: SMA period applied to %K, a positive integer (default 3).

  ## Examples

      iex> TAlib.Indicators.Stochastic.stochastic_d([1, 6, 2, 5, 3, 7, 4], 5, 3)
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
    k_values = prices |> stochastic_k_list(period) |> Enum.take(-d_period)

    if Enum.any?(k_values, &is_nil/1) do
      nil
    else
      MA.sma(k_values, d_period)
    end
  end

  defp k_over_window(window) do
    lowest_low = Enum.min(window)
    highest_high = Enum.max(window)
    range = highest_high - lowest_low

    if range == 0 do
      nil
    else
      (List.last(window) - lowest_low) / range * 100
    end
  end
end
