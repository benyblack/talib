defmodule TAlib.Indicators.BBands do
  alias TAlib.Indicators.MA
  alias TAlib.Indicators.StdDev

  @moduledoc """
  Bollinger Bands [Wikipedia](https://en.wikipedia.org/wiki/Bollinger_Bands).

  * middle = SMA(close, period)
  * upper = middle + mult * StdDev(close, period)
  * lower = middle - mult * StdDev(close, period)

  See `TAlib` for the input conventions: prices are always given in
  chronological order, oldest first. Every function returns `nil` when
  there is not enough data.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate the latest Bollinger Bands as a map.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: SMA lookback window, a positive integer (default 20).
    - mult: standard deviation multiplier, a number (default 2).

  ## Examples

      iex> %{upper: u, middle: m, lower: l} = TAlib.Indicators.BBands.bbands([1, 2, 3, 4, 5], 4, 2)
      iex> {Float.round(u, 4), Float.round(m, 4), Float.round(l, 4)}
      {5.7361, 3.5, 1.2639}
  """
  @spec bbands(list(number), pos_integer, number) ::
          %{
            upper: float,
            middle: float,
            lower: float
          }
          | nil
  def bbands(prices, period \\ 20, mult \\ 2)

  def bbands(_prices, period, _mult) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def bbands(_prices, _period, mult) when not is_number(mult),
    do: raise(ArgumentError, "mult must be a number, got: #{inspect(mult)}")

  def bbands(prices, period, _mult) when is_list(prices) and length(prices) < period, do: nil

  def bbands(prices, period, mult) when is_list(prices) do
    window = Enum.take(prices, -period)
    middle = MA.sma(window, period)
    deviation = StdDev.std_dev(window, period)

    %{upper: middle + mult * deviation, middle: middle, lower: middle - mult * deviation}
  end

  @doc """
  Calculate the full Bollinger Bands series.

  Returns a list aligned with `prices`: the first `period - 1` entries are
  `nil`, and every later entry is a map with `:upper`, `:middle` and
  `:lower`.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: SMA lookback window, a positive integer (default 20).
    - mult: standard deviation multiplier, a number (default 2).

  ## Examples

      iex> TAlib.Indicators.BBands.bbands_list([1, 2, 3, 4, 5], 4, 2) |> Enum.count(&is_nil/1)
      3
  """
  @spec bbands_list(list(number), pos_integer, number) :: list(map | nil)
  def bbands_list(prices, period \\ 20, mult \\ 2)

  def bbands_list(_prices, period, _mult) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def bbands_list(_prices, _period, mult) when not is_number(mult),
    do: raise(ArgumentError, "mult must be a number, got: #{inspect(mult)}")

  def bbands_list(prices, period, _mult) when is_list(prices) and length(prices) < period,
    do: List.duplicate(nil, length(prices))

  def bbands_list(prices, period, mult) when is_list(prices) do
    bands =
      prices
      |> Enum.chunk_every(period, 1, :discard)
      |> Enum.map(fn window ->
        middle = MA.sma(window, period)
        deviation = StdDev.std_dev(window, period)

        %{upper: middle + mult * deviation, middle: middle, lower: middle - mult * deviation}
      end)

    List.duplicate(nil, period - 1) ++ bands
  end
end
