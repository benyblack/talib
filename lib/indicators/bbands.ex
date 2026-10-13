defmodule TAlib.Indicators.BBands do
  alias TAlib.Indicators.Roll
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
    bands = sliding_bands(prices, period, mult)
    List.duplicate(nil, period - 1) ++ bands
  end

  # One pass with the same sliding sum and sum-of-squares the StdDev
  # walk keeps, so each bar costs O(1) instead of re-reading its
  # window: middle from the sliding sum, deviation from the sliding
  # sum of squares (`StdDev.std_dev_list`'s arithmetic exactly).
  defp sliding_bands(prices, period, mult) do
    window = Enum.take(prices, period)
    sum = Enum.sum(window)
    sq_sum = Enum.reduce(window, 0, fn price, acc -> acc + price * price end)

    {bands, _sum, _sq, _older} =
      Enum.reduce(
        Enum.drop(prices, period),
        {[band(sum, sq_sum, period, mult)], sum, sq_sum, prices},
        fn price, {acc, sum, sq_sum, [leaving | older]} ->
          sum = sum - leaving + price
          sq_sum = sq_sum - leaving * leaving + price * price
          {[band(sum, sq_sum, period, mult) | acc], sum, sq_sum, older}
        end
      )

    Enum.reverse(bands)
  end

  defp band(sum, sq_sum, period, mult) do
    middle = sum / period
    deviation = :math.sqrt(max(sq_sum - sum * sum / period, 0) / period)
    %{upper: middle + mult * deviation, middle: middle, lower: middle - mult * deviation}
  end

  # ------------------------------------------------------------------
  # Streaming: O(1) per price. `init` replays the history through the
  # same sliding sums `bbands_list/3` keeps, so its series equals the
  # batch series exactly and `next/2` continues it bit for bit.
  # ------------------------------------------------------------------

  defmodule State do
    @moduledoc false
    @type t :: %__MODULE__{}
    defstruct [:period, :mult, :sums, :squares]
  end

  @doc """
  Warm up streaming Bollinger Bands state from `history`.

  Returns `{state, values}` with `values` the full bands series of
  `history` (identical to `bbands_list/3`), and `state` ready to
  continue it one price at a time in O(1) via `next/2`. History needs
  at least `period` prices.

  ## Examples

      iex> {state, values} = TAlib.Indicators.BBands.init([1, 2, 3, 4, 5], 4, 2)
      iex> List.last(values)
      %{upper: 5.73606797749979, lower: 1.2639320225002102, middle: 3.5}
      iex> {_state, %{upper: u, middle: 4.5, lower: l}} = TAlib.Indicators.BBands.next(state, 6)
      iex> {Float.round(u, 4), Float.round(l, 4)}
      {6.7361, 2.2639}
  """
  @spec init(list(number), pos_integer, number) :: {State.t(), list(map | nil)}
  def init(prices, period \\ 20, mult \\ 2)

  def init(_prices, period, _mult) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def init(_prices, _period, mult) when not is_number(mult),
    do: raise(ArgumentError, "mult must be a number, got: #{inspect(mult)}")

  def init(prices, period, mult) when is_list(prices) do
    if length(prices) < period,
      do: raise(ArgumentError, "init needs at least period (#{period}) prices")

    state = %State{
      period: period,
      mult: mult,
      sums: Roll.sum_new(period),
      squares: Roll.sum_new(period)
    }

    Roll.replay(prices, state, &next/2)
  end

  @doc """
  Advance streaming Bollinger Bands state by one price, in O(1):
  `{state, %{upper: , middle: , lower: }}`.

      iex> {state, _} = TAlib.Indicators.BBands.init([1, 2, 3, 4, 5], 4, 2)
      iex> {_state, %{upper: u, middle: m, lower: l}} = TAlib.Indicators.BBands.next(state, 6)
      iex> {Float.round(u, 4), m, Float.round(l, 4)}
      {6.7361, 4.5, 2.2639}
  """
  @spec next(State.t(), number) :: {State.t(), map | nil}
  def next(%State{period: period, mult: mult, sums: sums, squares: squares} = state, price) do
    {sums, _} = Roll.sum_push(sums, price)
    {squares, _} = Roll.sum_push(squares, price * price)
    state = %{state | sums: sums, squares: squares}

    if sums.filled do
      {state, band(sums.sum, squares.sum, period, mult)}
    else
      {state, nil}
    end
  end
end
