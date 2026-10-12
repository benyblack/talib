defmodule TAlib.Indicators.Keltner do
  alias TAlib.Indicators.ATR
  alias TAlib.Indicators.MA

  @moduledoc """
  Keltner Channels [Wikipedia](https://en.wikipedia.org/wiki/Keltner_channel).

  * middle = EMA(close, period)
  * upper = middle + mult * ATR(period)
  * lower = middle - mult * ATR(period)

  The EMA and ATR are both seeded at index `period - 1`, so the channels
  are defined for the same points. Bars are maps with at least `:high`,
  `:low` and `:close`. See `TAlib` for the remaining conventions:
  chronological order, oldest first, `nil` when there is not enough data.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate the latest Keltner Channels as a map.

  ## Parameters

    - bars: list of bars, oldest first.
    - period: EMA/ATR lookback window, a positive integer (default 20).
    - mult: ATR multiplier, a number (default 2).

  ## Examples

      iex> bars = [
      ...>   %{high: 12, low: 8, close: 10},
      ...>   %{high: 11, low: 9, close: 10},
      ...>   %{high: 13, low: 9, close: 12}
      ...> ]
      iex> %{upper: u, middle: m, lower: l} = TAlib.Indicators.Keltner.keltner(bars, 2, 2)
      iex> {Float.round(u, 4), Float.round(m, 4), Float.round(l, 4)}
      {18.3333, 11.3333, 4.3333}
  """
  @spec keltner(list(map), pos_integer, number) ::
          %{
            upper: float,
            middle: float,
            lower: float
          }
          | nil
  def keltner(bars, period \\ 20, mult \\ 2)

  def keltner(_bars, period, _mult) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def keltner(_bars, _period, mult) when not is_number(mult),
    do: raise(ArgumentError, "mult must be a number, got: #{inspect(mult)}")

  def keltner(bars, period, _mult) when is_list(bars) and length(bars) < period, do: nil

  def keltner(bars, period, mult) when is_list(bars) do
    middle = MA.ema(closes(bars), period)
    deviation = mult * ATR.atr(bars, period)

    %{upper: middle + deviation, middle: middle, lower: middle - deviation}
  end

  @doc """
  Calculate the full Keltner Channels series.

  Returns a list aligned with `bars`: the first `period - 1` entries are
  `nil`, and every later entry is a map with `:upper`, `:middle` and
  `:lower`.

  ## Parameters

    - bars: list of bars, oldest first.
    - period: EMA/ATR lookback window, a positive integer (default 20).
    - mult: ATR multiplier, a number (default 2).

  ## Examples

      iex> bars = [
      ...>   %{high: 12, low: 8, close: 10},
      ...>   %{high: 11, low: 9, close: 10},
      ...>   %{high: 13, low: 9, close: 12}
      ...> ]
      iex> TAlib.Indicators.Keltner.keltner_list(bars, 2) |> Enum.count(&is_nil/1)
      1
  """
  @spec keltner_list(list(map), pos_integer, number) :: list(map | nil)
  def keltner_list(bars, period \\ 20, mult \\ 2)

  def keltner_list(_bars, period, _mult) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def keltner_list(_bars, _period, mult) when not is_number(mult),
    do: raise(ArgumentError, "mult must be a number, got: #{inspect(mult)}")

  def keltner_list(bars, period, mult) when is_list(bars) do
    emas = MA.ema_list(closes(bars), period)
    atrs = ATR.atr_list(bars, period)

    emas
    |> Enum.zip(atrs)
    |> Enum.map(fn
      {nil, _} -> nil
      {_, nil} -> nil
      {middle, atr} -> %{upper: middle + mult * atr, middle: middle, lower: middle - mult * atr}
    end)
  end

  defp closes(bars), do: Enum.map(bars, & &1.close)
end
