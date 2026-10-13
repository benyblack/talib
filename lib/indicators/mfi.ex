defmodule TAlib.Indicators.MFI do
  @moduledoc """
  Money Flow Index [Wikipedia](https://en.wikipedia.org/wiki/Money_flow_index).

  With the typical price `TP = (high + low + close) / 3` and the raw money
  flow `TP * volume`, over the lookback window:

  `MFI = 100 - 100 / (1 + positive_flow / negative_flow)`

  Bars are maps with at least `:high`, `:low`, `:close` and `:volume`. See
  `TAlib` for the remaining conventions: chronological order, oldest
  first, series aligned with the input, `nil` when there is not enough
  data or the window has no movement.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate the latest Money Flow Index.

  ## Parameters

    - bars: list of bars, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> bars = [
      ...>   %{high: 12, low: 8, close: 10, volume: 100},
      ...>   %{high: 13, low: 9, close: 12, volume: 200},
      ...>   %{high: 11, low: 9, close: 10, volume: 150}
      ...> ]
      iex> TAlib.Indicators.MFI.mfi(bars, 2) |> Float.round(4)
      60.177
  """
  @spec mfi(list(map), pos_integer) :: float | nil
  def mfi(bars, period \\ 14)

  def mfi(_bars, period) when not is_valid_period(period), do: TAlib.invalid_period!(period)

  def mfi(bars, period) when is_list(bars) and length(bars) <= period, do: nil

  def mfi(bars, period) when is_list(bars), do: List.last(mfi_list(bars, period))

  @doc """
  Calculate the full Money Flow Index series.

  Returns a list aligned with `bars`: the first `period` entries are
  `nil`, and every later entry is the MFI of the window ending at that
  point.

  ## Parameters

    - bars: list of bars, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> bars = [
      ...>   %{high: 12, low: 8, close: 10, volume: 100},
      ...>   %{high: 13, low: 9, close: 12, volume: 200},
      ...>   %{high: 11, low: 9, close: 10, volume: 150}
      ...> ]
      iex> TAlib.Indicators.MFI.mfi_list(bars, 2) |> Enum.map(fn
      ...>   nil -> nil
      ...>   x -> Float.round(x, 4)
      ...> end)
      [nil, nil, 60.177]
  """
  @spec mfi_list(list(map), pos_integer) :: list(float | nil)
  def mfi_list(bars, period \\ 14)

  def mfi_list(_bars, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def mfi_list(bars, period) when is_list(bars) do
    tps = typical_prices(bars)
    flows = Enum.map(bars, fn bar -> typical_price(bar) * bar.volume end)
    # flow_t counts as positive/negative by the change from TP_{t-1}
    directions = [0 | direction_walk(tps, [])]

    nils = List.duplicate(nil, min(period, length(bars)))

    # The first flow has no previous typical price to compare against, so
    # the earliest usable window starts at the second bar.
    nils ++ slide_mfi(tl(flows), tl(directions), period, [])
  end

  defp direction_walk([prev, cur | rest], acc),
    do: direction_walk([cur | rest], [compare(cur, prev) | acc])

  defp direction_walk([_single], acc), do: Enum.reverse(acc)
  defp direction_walk([], acc), do: Enum.reverse(acc)

  defp slide_mfi(flows, _directions, period, acc) when length(flows) < period,
    do: Enum.reverse(acc)

  defp slide_mfi(flows, directions, period, acc) do
    window_flows = Enum.take(flows, period)
    window_directions = Enum.take(directions, period)

    positive = sum_directed(window_flows, window_directions, 1)
    negative = sum_directed(window_flows, window_directions, -1)

    value =
      cond do
        positive == 0 and negative == 0 -> nil
        negative == 0 -> 100.0
        true -> 100.0 - 100.0 / (1.0 + positive / negative)
      end

    slide_mfi(tl(flows), tl(directions), period, [value | acc])
  end

  defp sum_directed(flows, directions, sign) do
    flows
    |> Enum.zip(directions)
    |> Enum.reduce(0, fn {flow, direction}, acc ->
      if direction == sign, do: acc + flow, else: acc
    end)
  end

  defp typical_prices(bars), do: Enum.map(bars, &typical_price/1)

  defp typical_price(%{high: high, low: low, close: close}), do: (high + low + close) / 3

  defp compare(a, b) when a > b, do: 1
  defp compare(a, b) when a < b, do: -1
  defp compare(_, _), do: 0
end
