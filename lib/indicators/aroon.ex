defmodule TAlib.Indicators.Aroon do
  alias TAlib.Indicators.Roll
  alias TAlib.Indicators.Window

  @moduledoc """
  Aroon indicator [Wikipedia](https://en.wikipedia.org/wiki/Aroon).

  * `Aroon Up = 100 * index of the window's highest high / period`
  * `Aroon Down = 100 * index of the window's lowest low / period`

  The window spans `period + 1` prices (or bars), so 100 means the
  extreme is the latest value and 0 means it is `period` bars old. On
  ties the earliest occurrence in the window wins. `Aroon Oscillator =
  Up - Down`. See `TAlib` for the conventions: chronological input,
  series aligned with the input, `nil` for insufficient data.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate the latest Aroon Up / Down as a map, over closing prices.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.Aroon.aroon([5, 3, 8, 2, 6, 9, 4], 3) |> Enum.sort()
      [down: 0.0, up: 66.66666666666667]
  """
  @spec aroon(list(number), pos_integer) :: %{up: float, down: float} | nil
  def aroon(prices, period \\ 14)

  def aroon(_prices, period) when not is_valid_period(period), do: TAlib.invalid_period!(period)

  def aroon(prices, period) when is_list(prices) and length(prices) < period + 1, do: nil

  def aroon(prices, period) when is_list(prices) do
    window = Enum.take(prices, -(period + 1))

    %{
      up: 100 * extreme_index(window, &>/2) / period,
      down: 100 * extreme_index(window, &</2) / period
    }
  end

  # Index of the maximal (or minimal) value in the window, earliest tie
  # wins: only a strictly better value replaces the current extreme.
  defp extreme_index(window, compare) do
    window
    |> Enum.with_index()
    |> Enum.reduce(fn {value, index}, {best, best_index} ->
      if compare.(value, best), do: {value, index}, else: {best, best_index}
    end)
    |> elem(1)
  end

  @doc """
  The Aroon Up / Down series over closing prices, aligned with the input
  (`period` leading `nil`s).

      iex> TAlib.Indicators.Aroon.aroon_list([5, 3, 8, 2, 6, 9, 4], 3) |> Enum.take(-2)
      [{100.0, 33.333333333333336}, {66.66666666666667, 0.0}]
  """
  @spec aroon_list(list(number), pos_integer) :: list({float, float} | nil)
  def aroon_list(prices, period \\ 14)

  def aroon_list(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def aroon_list(prices, period) when is_list(prices) and length(prices) < period + 1,
    do: List.duplicate(nil, length(prices))

  def aroon_list(prices, period) when is_list(prices) do
    values =
      prices
      |> Window.extremes(period + 1)
      |> Enum.with_index(fn {max_idx, min_idx}, k ->
        window_start = k
        {100 * (max_idx - window_start) / period, 100 * (min_idx - window_start) / period}
      end)

    List.duplicate(nil, period) ++ values
  end

  @doc """
  The Aroon Oscillator: `Up - Down`, ranging from -100 to 100.

      iex> TAlib.Indicators.Aroon.aroon_osc([5, 3, 8, 2, 6, 9, 4], 3) |> Float.round(4)
      66.6667
  """
  @spec aroon_osc(list(number), pos_integer) :: float | nil
  def aroon_osc(prices, period \\ 14)

  def aroon_osc(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def aroon_osc(prices, period) when is_list(prices) and length(prices) < period + 1, do: nil

  def aroon_osc(prices, period) when is_list(prices) do
    %{up: up, down: down} = aroon(prices, period)
    up - down
  end

  # ------------------------------------------------------------------
  # Streaming: O(1) per price. The monotonic deques carry each
  # extreme's tick along with its value, so the days-since-extreme
  # falls out the same way `Window.extremes/2` produces it for
  # `aroon_list/2`; `init`'s series equals the batch series exactly
  # and `next/2` continues it bit for bit.
  # ------------------------------------------------------------------

  defmodule State do
    @moduledoc false
    @type t :: %__MODULE__{}
    defstruct [:period, :max, :min]
  end

  @doc """
  Warm up streaming Aroon state from `history` (closing prices).

  Returns `{state, values}` with `values` the full `{up, down}` series
  of `history` (identical to `aroon_list/2`), and `state` ready to
  continue it one price at a time in O(1) via `next/2`. History needs
  at least `period + 1` prices.

  ## Examples

      iex> {state, values} = TAlib.Indicators.Aroon.init([5, 3, 8, 2, 6, 9, 4], 3)
      iex> Enum.take(values, -2)
      [{100.0, 33.333333333333336}, {66.66666666666667, 0.0}]
      iex> {_state, {100.0, 66.66666666666667}} = TAlib.Indicators.Aroon.next(state, 10)
  """
  @spec init(list(number), pos_integer) :: {State.t(), list({float, float} | nil)}
  def init(prices, period \\ 14)

  def init(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def init(prices, period) when is_list(prices) do
    if length(prices) < period + 1,
      do: raise(ArgumentError, "init needs at least period + 1 (#{period + 1}) prices")

    state = %State{period: period, max: Roll.max_new(period + 1), min: Roll.min_new(period + 1)}
    Roll.replay(prices, state, &next/2)
  end

  @doc """
  Advance streaming Aroon state by one price, in O(1):
  `{state, {up, down}}`.

      iex> {state, _} = TAlib.Indicators.Aroon.init([5, 3, 8, 2, 6, 9, 4], 3)
      iex> {_state, value} = TAlib.Indicators.Aroon.next(state, 10)
      iex> value
      {100.0, 66.66666666666667}
  """
  @spec next(State.t(), number) :: {State.t(), {float, float} | nil}
  def next(%State{period: period, max: max, min: min} = state, price) do
    {max, max_pair} = Roll.max_push(max, price)
    {min, min_pair} = Roll.min_push(min, price)
    state = %{state | max: max, min: min}

    if is_nil(max_pair) do
      {state, nil}
    else
      window_start = max.tick - period
      up = 100 * (elem(max_pair, 0) - window_start) / period
      down = 100 * (elem(min_pair, 0) - window_start) / period
      {state, {up, down}}
    end
  end
end
