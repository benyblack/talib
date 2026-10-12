defmodule TAlib.Indicators.SAR do
  @moduledoc """
  Parabolic SAR [Wikipedia](https://en.wikipedia.org/wiki/Parabolic_SAR).

  The trend starts up when the second close is above the first, and the
  acceleration factor starts at `af_start` (default 0.02), stepping by
  `af_step` (default 0.02) on every new extreme, capped at `af_max`
  (default 0.2). Bars are maps with at least `:high`, `:low` and
  `:close`. See `TAlib` for the remaining conventions; values are defined
  from the second bar on.
  """

  @doc """
  Calculate the latest Parabolic SAR value.

  ## Parameters

    - bars: list of bars, oldest first.
    - af_start: initial acceleration factor (default 0.02).
    - af_step: acceleration factor increment (default 0.02).
    - af_max: acceleration factor cap (default 0.2).

  ## Examples

      iex> bars = [
      ...>   %{high: 10, low: 9, close: 9.5},
      ...>   %{high: 11, low: 9.5, close: 10.5},
      ...>   %{high: 12, low: 10, close: 11.5},
      ...>   %{high: 11.5, low: 9.5, close: 10.0},
      ...>   %{high: 12.5, low: 10.5, close: 12.0}
      ...> ]
      iex> TAlib.Indicators.SAR.sar(bars) |> Float.round(4)
      9.2352
  """
  @spec sar(list(map), number, number, number) :: number | nil
  def sar(bars, af_start \\ 0.02, af_step \\ 0.02, af_max \\ 0.2)

  def sar([], _af_start, _af_step, _af_max), do: nil

  def sar(bars, af_start, af_step, af_max) when is_list(bars),
    do: List.last(sar_list(bars, af_start, af_step, af_max))

  @doc """
  Calculate the full Parabolic SAR series.

  Returns a list aligned with `bars`: the first entry is `nil` (the trend
  needs two bars), every later entry is the SAR stop for that bar.

  ## Parameters

    - bars: list of bars, oldest first.
    - af_start: initial acceleration factor (default 0.02).
    - af_step: acceleration factor increment (default 0.02).
    - af_max: acceleration factor cap (default 0.2).

  ## Examples

      iex> bars = [
      ...>   %{high: 10, low: 9, close: 9.5},
      ...>   %{high: 11, low: 9.5, close: 10.5},
      ...>   %{high: 12, low: 10, close: 11.5}
      ...> ]
      iex> TAlib.Indicators.SAR.sar_list(bars)
      [nil, 9, 9]
  """
  @spec sar_list(list(map), number, number, number) :: list(number | nil)
  def sar_list(bars, af_start \\ 0.02, af_step \\ 0.02, af_max \\ 0.2)

  def sar_list([], _af_start, _af_step, _af_max), do: []

  def sar_list([_single], _af_start, _af_step, _af_max), do: [nil]

  def sar_list([first, second | rest], af_start, af_step, af_max) do
    if second.close > first.close do
      state = {first, second, true, min(first.low, second.low), max(first.high, second.high)}

      walk_sar(rest, state, af_start, af_step, af_max, [
        min(first.low, second.low),
        nil
      ])
    else
      state = {first, second, false, max(first.high, second.high), min(first.low, second.low)}

      walk_sar(rest, state, af_start, af_step, af_max, [
        max(first.high, second.high),
        nil
      ])
    end
  end

  # State: {two bars back, one bar back, trend, sar, extreme point}. The
  # stop is clamped against the last two bars' opposite extremes, and the
  # trend reverses (resetting to the extreme point) when penetrated.
  defp walk_sar([], _state, _af, _af_step, _af_max, acc), do: Enum.reverse(acc)

  defp walk_sar([bar | rest], {prev2, prev1, true, sar, ep}, af, af_step, af_max, acc) do
    new_sar = min(sar + af * (ep - sar), min(prev1.low, prev2.low))

    if bar.low < new_sar do
      state = {prev1, bar, false, ep, bar.high}
      walk_sar(rest, state, af_step, af_step, af_max, [ep | acc])
    else
      {new_ep, new_af} = accelerate(bar.high, ep, af, af_step, af_max)
      state = {prev1, bar, true, new_sar, new_ep}
      walk_sar(rest, state, new_af, af_step, af_max, [new_sar | acc])
    end
  end

  defp walk_sar([bar | rest], {prev2, prev1, false, sar, ep}, af, af_step, af_max, acc) do
    new_sar = max(sar + af * (ep - sar), max(prev1.high, prev2.high))

    if bar.high > new_sar do
      state = {prev1, bar, true, ep, bar.low}
      walk_sar(rest, state, af_step, af_step, af_max, [ep | acc])
    else
      {new_ep, new_af} = decelerate(bar.low, ep, af, af_step, af_max)
      state = {prev1, bar, false, new_sar, new_ep}
      walk_sar(rest, state, new_af, af_step, af_max, [new_sar | acc])
    end
  end

  defp accelerate(high, ep, af, af_step, af_max) do
    if high > ep, do: {high, min(af + af_step, af_max)}, else: {ep, af}
  end

  defp decelerate(low, ep, af, af_step, af_max) do
    if low < ep, do: {low, min(af + af_step, af_max)}, else: {ep, af}
  end

  @doc """
  The extended Parabolic SAR (TA-Lib SAREXT) with the standard start,
  step and maximum acceleration factors.

      iex> bars = [
      ...>   %{high: 10, low: 9, close: 9.5},
      ...>   %{high: 11, low: 9.5, close: 10.5},
      ...>   %{high: 12, low: 10, close: 11.5}
      ...> ]
      iex> TAlib.Indicators.SAR.sar_ext(bars)
      9
  """
  @spec sar_ext(list(map), number, number, number) :: number | nil
  def sar_ext(bars, af_start \\ 0.02, af_step \\ 0.02, af_max \\ 0.2)

  def sar_ext(bars, af_start, af_step, af_max) when is_list(bars),
    do: List.last(sar_ext_list(bars, af_start, af_step, af_max))

  def sar_ext_list(bars, af_start \\ 0.02, af_step \\ 0.02, af_max \\ 0.2)

  def sar_ext_list(bars, af_start, af_step, af_max) when is_list(bars),
    do: sar_list(bars, af_start, af_step, af_max)
end
