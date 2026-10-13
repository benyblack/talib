defmodule TAlib.Indicators.CCI do
  @moduledoc """
  Commodity Channel Index [Wikipedia](https://en.wikipedia.org/wiki/Commodity_channel_index).

  With the typical price `TP = (high + low + close) / 3`:

  `CCI = (TP - SMA(TP, period)) / (0.015 * mean_deviation)`

  where the mean deviation is the average of `|TP - SMA|` across the
  window. Bars are maps with at least `:high`, `:low` and `:close`. See
  `TAlib` for the remaining conventions: chronological order, oldest
  first, series aligned with the input, `nil` when there is not enough
  data or the deviation is zero.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate the latest CCI value.

  ## Parameters

    - bars: list of bars, oldest first.
    - period: lookback window, a positive integer (default 20).

  ## Examples

      iex> bars = [
      ...>   %{high: 12, low: 8, close: 10},
      ...>   %{high: 11, low: 9, close: 10},
      ...>   %{high: 13, low: 9, close: 12}
      ...> ]
      iex> TAlib.Indicators.CCI.cci(bars, 2) |> Float.round(4)
      66.6667
  """
  @spec cci(list(map), pos_integer) :: float | nil
  def cci(bars, period \\ 20)

  def cci(_bars, period) when not is_valid_period(period), do: TAlib.invalid_period!(period)

  def cci(bars, period) when is_list(bars) and length(bars) < period, do: nil

  def cci(bars, period) when is_list(bars) do
    bars |> typical_prices() |> Enum.take(-period) |> cci_over_window()
  end

  @doc """
  Calculate the full CCI series.

  Returns a list aligned with `bars`: the first `period - 1` entries are
  `nil`, and every later entry is the CCI of the window ending at that
  point.

  ## Parameters

    - bars: list of bars, oldest first.
    - period: lookback window, a positive integer (default 20).

  ## Examples

      iex> bars = [
      ...>   %{high: 12, low: 8, close: 10},
      ...>   %{high: 11, low: 9, close: 10},
      ...>   %{high: 13, low: 9, close: 12}
      ...> ]
      iex> TAlib.Indicators.CCI.cci_list(bars, 2) |> Enum.map(fn
      ...>   nil -> nil
      ...>   x -> Float.round(x, 4)
      ...> end)
      [nil, nil, 66.6667]
  """
  @spec cci_list(list(map), pos_integer) :: list(float | nil)
  def cci_list(bars, period \\ 20)

  def cci_list(_bars, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def cci_list(bars, period) when is_list(bars) and length(bars) < period,
    do: List.duplicate(nil, length(bars))

  def cci_list(bars, period) when is_list(bars) do
    tps = typical_prices(bars)
    tuple = List.to_tuple(tps)
    n = tuple_size(tuple)
    seed_sum = tps |> Enum.take(period) |> Enum.sum()

    # The mean rides a sliding sum, but the mean deviation is read
    # straight from the window (like TA-Lib, which also walks it).
    {values, _sum, _older} =
      Enum.reduce((period - 1)..(n - 1)//1, {[], seed_sum, tps}, fn i, {acc, sum, older} ->
        mean = sum / period

        deviation =
          mean_deviation(tuple, i - period + 1, i, mean, 0) / period

        value =
          if deviation == 0,
            do: nil,
            else: (elem(tuple, i) - mean) / (0.015 * deviation)

        {sum, older} =
          if i < n - 1 do
            {sum - hd(older) + elem(tuple, i + 1), tl(older)}
          else
            {sum, older}
          end

        {[value | acc], sum, older}
      end)

    List.duplicate(nil, period - 1) ++ Enum.reverse(values)
  end

  defp mean_deviation(_tuple, j, last, _mean, acc) when j > last, do: acc

  defp mean_deviation(tuple, j, last, mean, acc),
    do: mean_deviation(tuple, j + 1, last, mean, acc + abs(elem(tuple, j) - mean))

  defp typical_prices(bars) do
    Enum.map(bars, fn %{high: high, low: low, close: close} -> (high + low + close) / 3 end)
  end

  defp cci_over_window(window) do
    mean = Enum.sum(window) / length(window)
    deviation = Enum.reduce(window, 0, fn tp, acc -> acc + abs(tp - mean) end) / length(window)

    if deviation == 0 do
      nil
    else
      (List.last(window) - mean) / (0.015 * deviation)
    end
  end
end
