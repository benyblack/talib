defmodule TAlib.Indicators.VWAP do
  @moduledoc """
  Volume Weighted Average Price [Wikipedia](https://en.wikipedia.org/wiki/Volume-weighted_average_price).

  This is the **rolling** VWAP: over each lookback window it is
  `sum(TP * volume) / sum(volume)` with the typical price
  `TP = (high + low + close) / 3` — not the session-anchored variant that
  resets every trading day.

  Bars are maps with at least `:high`, `:low`, `:close` and `:volume`. See
  `TAlib` for the remaining conventions: chronological order, oldest
  first, series aligned with the input, `nil` when there is not enough
  data.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate the latest rolling VWAP.

  ## Parameters

    - bars: list of bars, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> bars = [
      ...>   %{high: 11, low: 9, close: 10, volume: 100},
      ...>   %{high: 12, low: 8, close: 11, volume: 300}
      ...> ]
      iex> TAlib.Indicators.VWAP.vwap(bars, 2)
      10.25
  """
  @spec vwap(list(map), pos_integer) :: float | nil
  def vwap(bars, period \\ 14)

  def vwap(_bars, period) when not is_valid_period(period), do: TAlib.invalid_period!(period)

  def vwap(bars, period) when is_list(bars) and length(bars) < period, do: nil

  def vwap(bars, period) when is_list(bars),
    do: bars |> Enum.take(-period) |> window_vwap()

  @doc """
  Calculate the full rolling VWAP series in a single pass (sliding
  price-volume and volume sums).

  Returns a list aligned with `bars`: the first `period - 1` entries are
  `nil`, and every later entry is the volume-weighted average price of
  the window ending at that point.

  ## Parameters

    - bars: list of bars, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> bars = [
      ...>   %{high: 11, low: 9, close: 10, volume: 100},
      ...>   %{high: 12, low: 8, close: 11, volume: 300}
      ...> ]
      iex> TAlib.Indicators.VWAP.vwap_list(bars, 2)
      [nil, 10.25]
  """
  @spec vwap_list(list(map), pos_integer) :: list(float | nil)
  def vwap_list(bars, period \\ 14)

  def vwap_list(_bars, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def vwap_list(bars, period) when is_list(bars) and length(bars) < period,
    do: List.duplicate(nil, length(bars))

  def vwap_list(bars, period) when is_list(bars) do
    pv = Enum.map(bars, fn bar -> typical_price(bar) * bar.volume end)
    vols = Enum.map(bars, & &1.volume)

    initial_pv = Enum.sum(Enum.take(pv, period))
    initial_v = Enum.sum(Enum.take(vols, period))

    initial_value = if initial_v == 0, do: nil, else: initial_pv / initial_v

    List.duplicate(nil, period - 1) ++
      [
        initial_value
        | slide_vwap(
            pv,
            vols,
            Enum.drop(pv, period),
            Enum.drop(vols, period),
            initial_pv,
            initial_v,
            []
          )
      ]
  end

  defp slide_vwap(_pv, _vols, [], [], _pv_sum, _v_sum, acc), do: Enum.reverse(acc)

  defp slide_vwap(
         [leave_pv | pv],
         [leave_v | vols],
         [add_pv | ahead_pv],
         [add_v | ahead_v],
         pv_sum,
         v_sum,
         acc
       ) do
    new_pv_sum = pv_sum - leave_pv + add_pv
    new_v_sum = v_sum - leave_v + add_v

    value = if new_v_sum == 0, do: nil, else: new_pv_sum / new_v_sum

    slide_vwap(pv, vols, ahead_pv, ahead_v, new_pv_sum, new_v_sum, [value | acc])
  end

  defp typical_price(%{high: high, low: low, close: close}), do: (high + low + close) / 3

  defp window_vwap(window) do
    pv = Enum.reduce(window, 0, fn bar, acc -> acc + typical_price(bar) * bar.volume end)
    v = Enum.reduce(window, 0, &(&1.volume + &2))

    if v == 0, do: nil, else: pv / v
  end
end
