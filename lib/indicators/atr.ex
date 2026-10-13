defmodule TAlib.Indicators.ATR do
  alias TAlib.Indicators.MA

  @moduledoc """
  Average True Range [Wikipedia](https://en.wikipedia.org/wiki/Average_true_range).

  The True Range of a bar is `max(high - low, |high - prev_close|,
  |low - prev_close|)` (just `high - low` for the first bar). ATR is
  Wilder's smoothed average (RMA) of the True Range series, seeded with
  the SMA of the first `period` True Ranges — the standard TA-Lib
  convention.

  Bars are maps with at least `:high`, `:low` and `:close`; extra keys
  are ignored. See `TAlib` for the remaining conventions: chronological
  order, oldest first, series aligned with the input, `nil` when there is
  not enough data.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate the latest Average True Range.

  ## Parameters

    - bars: list of bars, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> bars = [
      ...>   %{high: 12, low: 8, close: 10},
      ...>   %{high: 11, low: 9, close: 10},
      ...>   %{high: 13, low: 9, close: 12}
      ...> ]
      iex> TAlib.Indicators.ATR.atr(bars, 2)
      3.0
  """
  @spec atr(list(map), pos_integer) :: float | nil
  def atr(bars, period \\ 14)

  def atr(_bars, period) when not is_valid_period(period), do: TAlib.invalid_period!(period)

  def atr(bars, period) when is_list(bars) and length(bars) < period + 1, do: nil

  def atr(bars, period) when is_list(bars),
    do: List.last(MA.rma_list(tl(true_ranges(bars)), period))

  @doc """
  Calculate the full ATR series.

  Returns a list aligned with `bars`: the first `period - 1` entries are
  `nil`, and every later entry is the Wilder-smoothed average of the True
  Ranges as of that point.

  ## Parameters

    - bars: list of bars, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> bars = [
      ...>   %{high: 12, low: 8, close: 10},
      ...>   %{high: 11, low: 9, close: 10},
      ...>   %{high: 13, low: 9, close: 12}
      ...> ]
      iex> TAlib.Indicators.ATR.atr_list(bars, 2)
      [nil, nil, 3.0]
  """
  @spec atr_list(list(map), pos_integer) :: list(float | nil)
  def atr_list(bars, period \\ 14)

  def atr_list(_bars, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  # The seed uses the close-based TRs of bars 1..period, so the RMA runs
  # over the True Ranges with the first (close-less) one dropped and the
  # nil shifted back onto bar 0 — exactly the TA-Lib alignment.
  def atr_list(bars, period) when is_list(bars),
    do: [nil | MA.rma_list(tl(true_ranges(bars)), period)]

  defp true_ranges([%{high: high, low: low, close: close} | rest]),
    do: true_range_walk(rest, close, [high - low])

  defp true_ranges([]), do: []

  defp true_range_walk([], _prev_close, acc), do: Enum.reverse(acc)

  defp true_range_walk([%{high: high, low: low, close: close} | rest], prev_close, acc) do
    tr = max(high - low, max(abs(high - prev_close), abs(low - prev_close)))
    true_range_walk(rest, close, [tr | acc])
  end

  @doc """
  The True Range of every bar: `max(high - low, |high - prev_close|,
  |low - prev_close|)` (`high - low` for the first bar).

      iex> bars = [
      ...>   %{high: 12, low: 8, close: 10},
      ...>   %{high: 11, low: 9, close: 10},
      ...>   %{high: 13, low: 9, close: 12}
      ...> ]
      iex> TAlib.Indicators.ATR.true_range(bars)
      [4, 2, 4]
  """
  @spec true_range(list(map)) :: list(number)
  def true_range(bars) when is_list(bars), do: true_ranges(bars)

  @doc """
  The Normalized ATR: `ATR / close * 100`, in percent.

      iex> bars = [
      ...>   %{high: 12, low: 8, close: 10},
      ...>   %{high: 11, low: 9, close: 10},
      ...>   %{high: 13, low: 9, close: 12}
      ...> ]
      iex> TAlib.Indicators.ATR.natr(bars, 2) |> Float.round(4)
      25.0
  """
  @spec natr(list(map), pos_integer) :: float | nil
  def natr(bars, period \\ 14)

  def natr(_bars, period) when not is_valid_period(period), do: TAlib.invalid_period!(period)

  def natr(bars, period) when is_list(bars) and length(bars) < period, do: nil

  def natr(bars, period) when is_list(bars) do
    close = List.last(bars).close

    if close == 0, do: nil, else: atr(bars, period) / close * 100
  end
end
