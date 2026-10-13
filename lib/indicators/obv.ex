defmodule TAlib.Indicators.OBV do
  @moduledoc """
  On-Balance Volume [Wikipedia](https://en.wikipedia.org/wiki/On-balance_volume).

  A running total of volume, added when the close rises and subtracted
  when it falls. Matching TA-Lib, the line is seeded with the first
  bar's volume; the first bar itself carries no change.

  Bars are maps with at least `:close` and `:volume`. See `TAlib` for the
  remaining conventions: chronological order, oldest first, series
  aligned with the input.
  """

  @doc """
  Calculate the latest On-Balance Volume.

  ## Parameters

    - bars: list of bars, oldest first.

  ## Examples

      iex> bars = [
      ...>   %{close: 5, volume: 10},
      ...>   %{close: 6, volume: 20},
      ...>   %{close: 5, volume: 30},
      ...>   %{close: 7, volume: 40}
      ...> ]
      iex> TAlib.Indicators.OBV.obv(bars)
      40
  """
  @spec obv(list(map)) :: number | nil
  def obv([]), do: nil

  def obv(bars) when is_list(bars), do: List.last(obv_list(bars))

  @doc """
  Calculate the full On-Balance Volume series.

  Returns a list aligned with `bars` (the first entry is the first
  bar's volume, as in TA-Lib).

  ## Parameters

    - bars: list of bars, oldest first.

  ## Examples

      iex> bars = [
      ...>   %{close: 5, volume: 10},
      ...>   %{close: 6, volume: 20},
      ...>   %{close: 5, volume: 30},
      ...>   %{close: 7, volume: 40}
      ...> ]
      iex> TAlib.Indicators.OBV.obv_list(bars)
      [10, 30, 0, 40]
  """
  @spec obv_list(list(map)) :: list(number)
  def obv_list([]), do: []

  def obv_list([%{close: close, volume: volume} | rest]) do
    obv_walk(rest, close, volume, [volume])
  end

  defp obv_walk([], _prev_close, _total, acc), do: Enum.reverse(acc)

  defp obv_walk([%{close: close, volume: volume} | rest], prev_close, total, acc) do
    delta =
      cond do
        close > prev_close -> volume
        close < prev_close -> -volume
        true -> 0
      end

    obv_walk(rest, close, total + delta, [total + delta | acc])
  end
end
