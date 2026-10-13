defmodule TAlib.Indicators.Donchian do
  alias TAlib.Indicators.Roll
  alias TAlib.Indicators.Window

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

  def donchian(bars, period) when is_list(bars) do
    window = Enum.take(bars, -period)
    highest = window |> Enum.map(& &1.high) |> Enum.max()
    lowest = window |> Enum.map(& &1.low) |> Enum.min()
    %{upper: highest, middle: (highest + lowest) / 2, lower: lowest}
  end

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
    highs = Window.maxes(Enum.map(bars, & &1.high), period)
    lows = Window.mins(Enum.map(bars, & &1.low), period)

    values =
      highs
      |> Enum.zip(lows)
      |> Enum.map(fn {highest, lowest} ->
        %{upper: highest, middle: (highest + lowest) / 2, lower: lowest}
      end)

    List.duplicate(nil, period - 1) ++ values
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

  def midprice(bars, period) when is_list(bars) do
    window = Enum.take(bars, -period)
    highest = window |> Enum.map(& &1.high) |> Enum.max()
    lowest = window |> Enum.map(& &1.low) |> Enum.min()
    (highest + lowest) / 2
  end

  # ------------------------------------------------------------------
  # Streaming: O(1) per bar, rolling extremes via monotonic deques.
  # `init` replays the history through the same deque walk
  # `donchian_list/2` runs, so its series equals the batch series
  # exactly and `next/2` continues it bit for bit.
  # ------------------------------------------------------------------

  defmodule State do
    @moduledoc false
    @type t :: %__MODULE__{}
    defstruct [:period, :max, :min]
  end

  @doc """
  Warm up streaming Donchian Channels state from `history`.

  Returns `{state, values}` with `values` the full channel series of
  `history` (identical to `donchian_list/2`), and `state` ready to
  continue it one bar at a time in O(1) via `next/2`. History needs at
  least `period` bars.

  ## Examples

      iex> bars = [
      ...>   %{high: 12, low: 8, close: 10},
      ...>   %{high: 11, low: 9, close: 10},
      ...>   %{high: 13, low: 9, close: 12}
      ...> ]
      iex> {state, values} = TAlib.Indicators.Donchian.init(bars, 2)
      iex> values
      [nil, %{lower: 8, middle: 10.0, upper: 12}, %{lower: 9, middle: 11.0, upper: 13}]
      iex> {_state, %{lower: 7, middle: 10.5, upper: 14}} = TAlib.Indicators.Donchian.next(state, %{high: 14, low: 7})
  """
  @spec init(list(map), pos_integer) :: {State.t(), list(map | nil)}
  def init(bars, period \\ 20)

  def init(_bars, period) when not is_valid_period(period), do: TAlib.invalid_period!(period)

  def init(bars, period) when is_list(bars) do
    if length(bars) < period,
      do: raise(ArgumentError, "init needs at least period (#{period}) bars")

    state = %State{period: period, max: Roll.max_new(period), min: Roll.min_new(period)}
    Roll.replay(bars, state, &next/2)
  end

  @doc """
  Advance streaming Donchian Channels state by one bar (a map with at
  least `:high` and `:low`), in O(1): `{state, %{upper: , middle: ,
  lower: }}`.

      iex> {state, _} = TAlib.Indicators.Donchian.init([%{high: 12, low: 8}, %{high: 11, low: 9}, %{high: 13, low: 9}], 2)
      iex> {_state, channel} = TAlib.Indicators.Donchian.next(state, %{high: 14, low: 7})
      iex> channel
      %{lower: 7, middle: 10.5, upper: 14}
  """
  @spec next(State.t(), map) :: {State.t(), map | nil}
  def next(%State{max: max, min: min} = state, bar) do
    {max, max_pair} = Roll.max_push(max, bar.high)
    {min, min_pair} = Roll.min_push(min, bar.low)
    state = %{state | max: max, min: min}

    if is_nil(max_pair) do
      {state, nil}
    else
      highest = elem(max_pair, 1)
      lowest = elem(min_pair, 1)
      {state, %{upper: highest, middle: (highest + lowest) / 2, lower: lowest}}
    end
  end
end
