defmodule TAlib.Indicators.WilliamsR do
  alias TAlib.Indicators.Roll
  alias TAlib.Indicators.Window

  @moduledoc """
  Williams %R [Wikipedia](https://en.wikipedia.org/wiki/Williams_%25R).

  `%R = (Highest High - Close) / (Highest High - Lowest Low) * -100`

  Ranges from -100 (close at the window low) to 0 (close at the window
  high). See `TAlib` for the input conventions: prices are always given in
  chronological order, oldest first, and the series is returned aligned
  with the input. `nil` is returned when there is not enough data or the
  window has no range (flat prices), since %R is then undefined.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate the latest Williams %R.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.WilliamsR.williams_r([5, 9, 3, 8, 2, 6], 3) |> Float.round(4)
      -33.3333
  """
  @spec williams_r(list(number), pos_integer) :: float | nil
  def williams_r(prices, period \\ 14)

  def williams_r(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def williams_r(prices, period) when is_list(prices) and length(prices) < period, do: nil

  def williams_r(prices, period) when is_list(prices) do
    window = Enum.take(prices, -period)
    highest = Enum.max(window)
    lowest = Enum.min(window)

    if highest == lowest do
      nil
    else
      (highest - List.last(window)) / (highest - lowest) * -100
    end
  end

  @doc """
  Calculate the full Williams %R series.

  Returns a list aligned with `prices`: the first `period - 1` entries are
  `nil`, and every later entry is %R of the window ending at that point.
  Windows with no range produce `nil`.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.WilliamsR.williams_r_list([5, 9, 3, 8, 2, 6], 3) |> Enum.map(fn
      ...>   nil -> nil
      ...>   x -> Float.round(x, 4)
      ...> end)
      [nil, nil, -100.0, -16.6667, -100.0, -33.3333]
  """
  @spec williams_r_list(list(number), pos_integer) :: list(float | nil)
  def williams_r_list(prices, period \\ 14)

  def williams_r_list(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def williams_r_list(prices, period) when is_list(prices) and length(prices) < period,
    do: List.duplicate(nil, length(prices))

  def williams_r_list(prices, period) when is_list(prices) do
    values =
      prices
      |> Window.maxes_mins(period)
      |> Enum.zip(Enum.drop(prices, period - 1))
      |> Enum.map(fn
        {{highest, lowest}, close} when highest != lowest ->
          (highest - close) / (highest - lowest) * -100

        _ ->
          nil
      end)

    List.duplicate(nil, period - 1) ++ values
  end

  # ------------------------------------------------------------------
  # Streaming: O(1) per price, rolling extremes via monotonic deques.
  # `init` replays the history through the same deque walk
  # `williams_r_list/2` runs, so its series equals the batch series
  # exactly and `next/2` continues it bit for bit.
  # ------------------------------------------------------------------

  defmodule State do
    @moduledoc false
    @type t :: %__MODULE__{}
    defstruct [:period, :max, :min]
  end

  @doc """
  Warm up streaming Williams %R state from `history`.

  Returns `{state, values}` with `values` the full %R series of
  `history` (identical to `williams_r_list/2`), and `state` ready to
  continue it one price at a time in O(1) via `next/2`. History needs
  at least `period` prices.

  ## Examples

      iex> {state, values} = TAlib.Indicators.WilliamsR.init([5, 9, 3, 8, 2, 6], 3)
      iex> values |> Enum.map(fn x -> if is_nil(x), do: nil, else: Float.round(x, 4) end)
      [nil, nil, -100.0, -16.6667, -100.0, -33.3333]
      iex> {_state, -25.0} = TAlib.Indicators.WilliamsR.next(state, 5)
  """
  @spec init(list(number), pos_integer) :: {State.t(), list(float | nil)}
  def init(prices, period \\ 14)

  def init(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def init(prices, period) when is_list(prices) do
    if length(prices) < period,
      do: raise(ArgumentError, "init needs at least period (#{period}) prices")

    state = %State{period: period, max: Roll.max_new(period), min: Roll.min_new(period)}
    Roll.replay(prices, state, &next/2)
  end

  @doc """
  Advance streaming Williams %R state by one price, in O(1). A flat
  window (no range) yields `nil`, like the batch series.

      iex> {state, _} = TAlib.Indicators.WilliamsR.init([5, 9, 3, 8, 2, 6], 3)
      iex> {_state, value} = TAlib.Indicators.WilliamsR.next(state, 5)
      iex> value
      -25.0
  """
  @spec next(State.t(), number) :: {State.t(), float | nil}
  def next(%State{max: max, min: min} = state, price) do
    {max, max_pair} = Roll.max_push(max, price)
    {min, min_pair} = Roll.min_push(min, price)
    state = %{state | max: max, min: min}

    if is_nil(max_pair) do
      {state, nil}
    else
      highest = elem(max_pair, 1)
      lowest = elem(min_pair, 1)

      if highest != lowest do
        {state, (highest - price) / (highest - lowest) * -100}
      else
        {state, nil}
      end
    end
  end
end
