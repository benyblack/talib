defmodule TAlib.Indicators.ADX do
  alias TAlib.Indicators.MA

  @moduledoc """
  Average Directional Index [Wikipedia](https://en.wikipedia.org/wiki/Average_directional_movement_index).

  * `+DM` / `-DM`: the up-/down-move that exceeds the opposite move on a bar
  * `+DI` / `-DI`: `100 * RMA(+DM) / RMA(TR)` and its mirror (RMA = Wilder smoothing)
  * `DX = 100 * |+DI - -DI| / (+DI + -DI)`
  * `ADX = RMA(DX)`, seeded with the SMA of the first `period` DX values

  The directional lines are defined from index `period - 1` on and ADX from
  index `2 * period - 2` (i.e. `2 * period - 1` bars). Bars are maps with
  at least `:high`, `:low` and `:close`. See `TAlib` for the remaining
  conventions: chronological order, oldest first, `nil` when there is not
  enough data.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate the latest +DI (positive directional index).

  ## Parameters

    - bars: list of bars, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> bars = [
      ...>   %{high: 10, low: 5, close: 7},
      ...>   %{high: 11, low: 6, close: 9},
      ...>   %{high: 12, low: 7, close: 8},
      ...>   %{high: 11, low: 8, close: 10},
      ...>   %{high: 13, low: 9, close: 12}
      ...> ]
      iex> TAlib.Indicators.ADX.plus_di(bars, 3) |> Float.round(4)
      22.807
  """
  @spec plus_di(list(map), pos_integer) :: float | nil
  def plus_di(bars, period \\ 14)

  def plus_di(_bars, period) when not is_valid_period(period), do: TAlib.invalid_period!(period)

  def plus_di(bars, period) when is_list(bars) and length(bars) < period, do: nil

  def plus_di(bars, period) when is_list(bars),
    do: bars |> directional_lines(period) |> List.last()

  @doc """
  Calculate the latest -DI (negative directional index).

  ## Parameters

    - bars: list of bars, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> bars = [
      ...>   %{high: 10, low: 5, close: 7},
      ...>   %{high: 11, low: 6, close: 9},
      ...>   %{high: 12, low: 7, close: 8},
      ...>   %{high: 11, low: 8, close: 10},
      ...>   %{high: 13, low: 9, close: 12}
      ...> ]
      iex> TAlib.Indicators.ADX.minus_di(bars, 3)
      0.0
  """
  @spec minus_di(list(map), pos_integer) :: float | nil
  def minus_di(bars, period \\ 14)

  def minus_di(_bars, period) when not is_valid_period(period), do: TAlib.invalid_period!(period)

  def minus_di(bars, period) when is_list(bars) and length(bars) < period, do: nil

  def minus_di(bars, period) when is_list(bars),
    do: bars |> negative_directional_lines(period) |> List.last()

  @doc """
  Calculate the latest ADX value: Wilder's smoothed average of DX.

  ## Parameters

    - bars: list of bars, oldest first.
    - period: lookback window, a positive integer (default 14).

  At least `2 * period - 1` bars are required for the DX seed window;
  otherwise `nil` is returned.

  ## Examples

      iex> bars = [
      ...>   %{high: 10, low: 5, close: 7},
      ...>   %{high: 11, low: 6, close: 9},
      ...>   %{high: 12, low: 7, close: 8},
      ...>   %{high: 11, low: 8, close: 10},
      ...>   %{high: 13, low: 9, close: 12}
      ...> ]
      iex> TAlib.Indicators.ADX.adx(bars, 3)
      100.0
  """
  @spec adx(list(map), pos_integer) :: float | nil
  def adx(bars, period \\ 14)

  def adx(_bars, period) when not is_valid_period(period), do: TAlib.invalid_period!(period)

  def adx(bars, period) when is_list(bars) and length(bars) < 2 * period - 1, do: nil

  def adx(bars, period) when is_list(bars) do
    case adx_values(bars, period) do
      nil -> nil
      values -> List.last(values)
    end
  end

  @doc """
  Calculate +DI, -DI and ADX of the latest point in a single pass.

  ## Parameters

    - bars: list of bars, oldest first.
    - period: lookback window, a positive integer (default 14).

  Returns a map with `:plus_di`, `:minus_di` and `:adx`. Each value is
  `nil` when its own data requirement is not met, so the directional
  lines can be defined while ADX is still `nil`.

  ## Examples

      iex> bars = [
      ...>   %{high: 10, low: 5, close: 7},
      ...>   %{high: 11, low: 6, close: 9},
      ...>   %{high: 12, low: 7, close: 8},
      ...>   %{high: 11, low: 8, close: 10},
      ...>   %{high: 13, low: 9, close: 12}
      ...> ]
      iex> %{plus_di: p, minus_di: m, adx: a} = TAlib.Indicators.ADX.adx_all(bars, 3)
      iex> {Float.round(p, 4), Float.round(m, 4), Float.round(a, 4)}
      {22.807, 0.0, 100.0}
  """
  @spec adx_all(list(map), pos_integer) :: %{
          plus_di: float | nil,
          minus_di: float | nil,
          adx: float | nil
        }
  def adx_all(bars, period \\ 14)

  def adx_all(_bars, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def adx_all(bars, period) when is_list(bars) do
    plus_di = List.last(directional_lines(bars, period))
    minus_di = List.last(negative_directional_lines(bars, period))

    adx =
      case adx_values(bars, period) do
        nil -> nil
        values -> List.last(values)
      end

    %{plus_di: plus_di, minus_di: minus_di, adx: adx}
  end

  defp directional_lines(bars, period) do
    di_series(plus_dm_series(bars, period), smoothed_true_ranges(bars, period))
  end

  defp negative_directional_lines(bars, period) do
    di_series(minus_dm_series(bars, period), smoothed_true_ranges(bars, period))
  end

  defp smoothed_true_ranges(bars, period),
    do: MA.rma_list(true_range_series(bars), period)

  defp di_series(dm_series, tr_series) do
    dm_series
    |> Enum.zip(tr_series)
    |> Enum.map(fn
      {nil, _} -> nil
      {_, nil} -> nil
      {dm, tr} -> if tr == 0, do: nil, else: 100 * dm / tr
    end)
  end

  defp true_range_series([%{high: high, low: low, close: close} | rest]) do
    [high - low | tr_walk(rest, close, [])]
  end

  defp tr_walk([], _prev_close, acc), do: Enum.reverse(acc)

  defp tr_walk([%{high: high, low: low, close: close} | rest], prev_close, acc) do
    tr = max(high - low, max(abs(high - prev_close), abs(low - prev_close)))
    tr_walk(rest, close, [tr | acc])
  end

  # +DM/-DM per bar; the first bar has no previous bar to compare against.
  defp plus_dm_series([%{high: high, low: low} | rest], period) do
    {plus, _} = dm_walk(rest, {high, low}, {[0], [0]})
    MA.rma_list(plus, period)
  end

  defp minus_dm_series([%{high: high, low: low} | rest], period) do
    {_, minus} = dm_walk(rest, {high, low}, {[0], [0]})
    MA.rma_list(minus, period)
  end

  defp dm_walk([], _prev, {plus, minus}) do
    {Enum.reverse(plus), Enum.reverse(minus)}
  end

  defp dm_walk([%{high: high, low: low} | rest], {prev_high, prev_low}, {plus, minus}) do
    up = high - prev_high
    down = prev_low - low

    {plus_value, minus_value} =
      cond do
        up > down and up > 0 -> {up, 0}
        down > up and down > 0 -> {0, down}
        true -> {0, 0}
      end

    dm_walk(rest, {high, low}, {[plus_value | plus], [minus_value | minus]})
  end

  defp adx_values(bars, period) do
    dx =
      bars
      |> directional_lines(period)
      |> Enum.zip(negative_directional_lines(bars, period))
      |> Enum.reject(fn {p, m} -> is_nil(p) or is_nil(m) or p + m == 0 end)
      |> Enum.map(fn {p, m} -> 100 * abs(p - m) / (p + m) end)

    if length(dx) < period do
      nil
    else
      dx |> MA.rma_list(period) |> Enum.reject(&is_nil/1)
    end
  end
end
