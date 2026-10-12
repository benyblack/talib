defmodule TAlib.Indicators.Donchian do
  @moduledoc """
  Donchian Channels [Wikipedia](https://en.wikipedia.org/wiki/Donchian_channel).

  * upper = Highest High over the window
  * lower = Lowest Low over the window
  * middle = (upper + lower) / 2

  Bars are maps with at least `:high` and `:low`. See `TAlib` for the
  remaining conventions: chronological order, oldest first, series aligned
  with the input, `nil` when there is not enough data.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate the latest Donchian Channels as a map.

  ## Parameters

    - bars: list of bars, oldest first.
    - period: lookback window, a positive integer (default 20).

  ## Examples

      iex> bars = [
      ...>   %{high: 12, low: 8, close: 10},
      ...>   %{high: 11, low: 9, close: 10},
      ...>   %{high: 13, low: 9, close: 12}
      ...> ]
      iex> TAlib.Indicators.Donchian.donchian(bars, 3)
      %{lower: 8, middle: 10.5, upper: 13}
  """
  @spec donchian(list(map), pos_integer) :: %{upper: number, middle: float, lower: number} | nil
  def donchian(bars, period \\ 20)

  def donchian(_bars, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def donchian(bars, period) when is_list(bars) and length(bars) < period, do: nil

  def donchian(bars, period) when is_list(bars),
    do: bars |> Enum.take(-period) |> channel_over_bars()

  @doc """
  Calculate the full Donchian Channels series.

  Returns a list aligned with `bars`: the first `period - 1` entries are
  `nil`, and every later entry is a map with `:upper`, `:middle` and
  `:lower`.

  ## Parameters

    - bars: list of bars, oldest first.
    - period: lookback window, a positive integer (default 20).

  ## Examples

      iex> bars = [
      ...>   %{high: 12, low: 8, close: 10},
      ...>   %{high: 11, low: 9, close: 10},
      ...>   %{high: 13, low: 9, close: 12}
      ...> ]
      iex> TAlib.Indicators.Donchian.donchian_list(bars, 2)
      [nil, %{lower: 8, middle: 10.0, upper: 12}, %{lower: 9, middle: 11.0, upper: 13}]
  """
  @spec donchian_list(list(map), pos_integer) :: list(map | nil)
  def donchian_list(bars, period \\ 20)

  def donchian_list(_bars, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def donchian_list(bars, period) when is_list(bars) and length(bars) < period,
    do: List.duplicate(nil, length(bars))

  def donchian_list(bars, period) when is_list(bars) do
    values = bars |> Enum.chunk_every(period, 1, :discard) |> Enum.map(&channel_over_bars/1)
    List.duplicate(nil, period - 1) ++ values
  end

  defp channel_over_bars(window) do
    highest = window |> Enum.map(& &1.high) |> Enum.max()
    lowest = window |> Enum.map(& &1.low) |> Enum.min()
    %{upper: highest, middle: (highest + lowest) / 2, lower: lowest}
  end

  @doc """
  The Midprice of the `period` newest bars: `(highest high + lowest
  low) / 2` — the middle Donchian channel line on its own.

      iex> bars = [
      ...>   %{high: 12, low: 8, close: 10},
      ...>   %{high: 11, low: 9, close: 10},
      ...>   %{high: 13, low: 9, close: 12}
      ...> ]
      iex> TAlib.Indicators.Donchian.midprice(bars, 3)
      10.5
  """
  @spec midprice(list(map), pos_integer) :: float | nil
  def midprice(bars, period \\ 20)

  def midprice(_bars, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def midprice(bars, period) when is_list(bars) and length(bars) < period, do: nil

  def midprice(bars, period) when is_list(bars),
    do: bars |> Enum.take(-period) |> channel_over_bars() |> Map.fetch!(:middle)
end
