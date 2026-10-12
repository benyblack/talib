defmodule TAlib.Indicators.UltimateOsc do
  alias TAlib.Indicators.MA

  @moduledoc """
  Ultimate Oscillator [Wikipedia](https://en.wikipedia.org/wiki/Ultimate_oscillator).

  With the buying pressure `BP = close - min(low, prev_close)` and the
  true range `TR = max(high, prev_close) - min(low, prev_close)`, the
  oscillator blends three averages:

  `100 * (4 * A(short) + 2 * A(middle) + A(long)) / 7`

  where `A(p) = SMA(BP, p) / SMA(TR, p)`. Bars are maps with at least
  `:high`, `:low` and `:close`. See `TAlib` for the conventions; values
  are defined once the longest window fills.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate the latest Ultimate Oscillator value.

  ## Parameters

    - bars: list of bars, oldest first.
    - short: short window, a positive integer (default 7).
    - middle: middle window, a positive integer (default 14).
    - long: long window, a positive integer (default 28).

  ## Examples

      iex> bars = Enum.map(1..5, fn i ->
      ...>   %{high: i + 1.0, low: i - 1.0, close: i * 1.0}
      ...> end)
      iex> TAlib.Indicators.UltimateOsc.ultimate_osc(bars, 2, 3, 4)
      50.0
  """
  @spec ultimate_osc(list(map), pos_integer, pos_integer, pos_integer) :: float | nil
  def ultimate_osc(bars, short \\ 7, middle \\ 14, long \\ 28)

  def ultimate_osc(_bars, short, _middle, _long) when not is_valid_period(short),
    do: TAlib.invalid_period!(short)

  def ultimate_osc(_bars, _short, middle, _long) when not is_valid_period(middle),
    do: TAlib.invalid_period!(middle)

  def ultimate_osc(_bars, _short, _middle, long) when not is_valid_period(long),
    do: TAlib.invalid_period!(long)

  def ultimate_osc(bars, _short, _middle, long) when is_list(bars) and length(bars) < long,
    do: nil

  def ultimate_osc(bars, short, middle, long) when is_list(bars),
    do: List.last(ultimate_osc_series(bars, short, middle, long))

  @doc """
  Calculate the full Ultimate Oscillator series, defined from index
  `long - 1` on.

  ## Parameters

    - bars: list of bars, oldest first.
    - short: short window, a positive integer (default 7).
    - middle: middle window, a positive integer (default 14).
    - long: long window, a positive integer (default 28).
  """
  @spec ultimate_osc_list(list(map), pos_integer, pos_integer, pos_integer) ::
          list(float | nil)
  def ultimate_osc_list(bars, short \\ 7, middle \\ 14, long \\ 28)

  def ultimate_osc_list(_bars, short, _middle, _long) when not is_valid_period(short),
    do: TAlib.invalid_period!(short)

  def ultimate_osc_list(_bars, _short, middle, _long) when not is_valid_period(middle),
    do: TAlib.invalid_period!(middle)

  def ultimate_osc_list(_bars, _short, _middle, long) when not is_valid_period(long),
    do: TAlib.invalid_period!(long)

  def ultimate_osc_list(bars, _short, _middle, long) when is_list(bars) and length(bars) < long,
    do: List.duplicate(nil, length(bars))

  def ultimate_osc_list(bars, short, middle, long) when is_list(bars),
    do: ultimate_osc_series(bars, short, middle, long)

  defp ultimate_osc_series(bars, short, middle, long) do
    [%{high: high, low: low, close: close} | rest] = bars

    bp = [close - low | bp_walk(rest, close, [])]
    tr = [high - low | tr_walk(rest, close, [])]

    # Ratio of the averaged buying pressure to the averaged true range
    # per window, then all three aligned on their common (newest) tail.
    ratios_short = window_ratios(bp, tr, short)
    ratios_middle = window_ratios(bp, tr, middle)
    ratios_long = window_ratios(bp, tr, long)

    count =
      min(length(ratios_short), min(length(ratios_middle), length(ratios_long)))

    values =
      [ratios_short, ratios_middle, ratios_long]
      |> Enum.map(&Enum.take(&1, -count))
      |> Enum.zip()
      |> Enum.map(fn
        {nil, _, _} -> nil
        {_, nil, _} -> nil
        {_, _, nil} -> nil
        {a, b, c} -> 100 * (4 * a + 2 * b + c) / 7
      end)

    List.duplicate(nil, length(bars) - length(values)) ++ values
  end

  defp window_ratios(bp, tr, period) do
    bp_avgs = bp |> MA.sma_list(period) |> Enum.reject(&is_nil/1)
    tr_avgs = tr |> MA.sma_list(period) |> Enum.reject(&is_nil/1)

    Enum.zip(bp_avgs, tr_avgs)
    |> Enum.map(fn
      {_, 0} -> nil
      {bp_avg, tr_avg} -> bp_avg / tr_avg
    end)
  end

  defp bp_walk([], _prev_close, acc), do: Enum.reverse(acc)

  defp bp_walk([%{high: _high, low: low, close: close} | rest], prev_close, acc) do
    bp_walk(rest, close, [close - min(low, prev_close) | acc])
  end

  defp tr_walk([], _prev_close, acc), do: Enum.reverse(acc)

  defp tr_walk([%{high: high, low: low, close: close} | rest], prev_close, acc) do
    tr_walk(rest, close, [max(high, prev_close) - min(low, prev_close) | acc])
  end
end
