defmodule TAlib.Indicators.RSI do
  alias TAlib.Indicators.Roll

  @moduledoc """
  Relative Strength Index [Wikipedia](https://en.wikipedia.org/wiki/Relative_strength_index).

  Gain and loss averages use Wilder's smoothing (an RMA seeded with the
  SMA of the first `period` changes), matching TA-Lib. `nil` is returned
  when there is not enough data or the window has no movement (RSI is
  undefined). See `TAlib` for the input conventions.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate RSI for each point of a price series in a single pass
  (Wilder-smoothed gain/loss averages).

  Returns a list aligned with `data`: the first `period` entries are `nil`,
  and every later entry is the RSI of the window ending at that point.

  ## Parameters

    - data: list of prices, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.RSI.rsi_list([1, 2, 3, 4, 5], 3)
      [nil, nil, nil, 100.0, 100.0]
  """
  @spec rsi_list(list(number), pos_integer) :: list(float | nil)
  def rsi_list(data, period \\ 14)

  def rsi_list(_data, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def rsi_list([], _period), do: []

  def rsi_list(data, period) when is_list(data) and length(data) <= period,
    do: List.duplicate(nil, length(data))

  def rsi_list(data, period) when is_list(data) do
    changes = window_changes(data)
    gains = Enum.map(changes, &max(&1, 0))
    losses = Enum.map(changes, &max(-&1, 0))

    gain_avg = Enum.sum(Enum.take(gains, period)) / period
    loss_avg = Enum.sum(Enum.take(losses, period)) / period

    {values, _} =
      Enum.reduce(
        Enum.zip(Enum.drop(gains, period), Enum.drop(losses, period)),
        {[rsi_from_sums(gain_avg, loss_avg)], {gain_avg, loss_avg}},
        fn {gain, loss}, {acc, {g, l}} ->
          new_g = (g * (period - 1) + gain) / period
          new_l = (l * (period - 1) + loss) / period
          {[rsi_from_sums(new_g, new_l) | acc], {new_g, new_l}}
        end
      )

    List.duplicate(nil, period) ++ Enum.reverse(values)
  end

  @doc """
  Calculate RSI over the `period` newest price changes, with Wilder's
  smoothing (matching TA-Lib).

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.RSI.rsi([1, 2, 3, 4, 5, 6], 3)
      100.0

      iex> TAlib.Indicators.RSI.rsi([6, 1, 4, 2, 5, 3], 3) |> Float.round(4)
      39.4737
  """
  @spec rsi(list(number), pos_integer) :: float | nil
  def rsi(prices, period \\ 14)

  def rsi(_prices, period) when not is_valid_period(period), do: TAlib.invalid_period!(period)

  def rsi([], _period), do: nil

  def rsi(prices, period) when is_list(prices) and length(prices) <= period, do: nil

  def rsi(prices, period) when is_list(prices), do: List.last(rsi_list(prices, period))

  @doc """
  Wilder-smoothed average gain over the `period` newest price changes.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.RSI.average_gain([1, 2, 3, 4, 5, 6], 3) |> Float.round(4)
      1.0
  """
  @spec average_gain(list(number), pos_integer) :: float | nil
  def average_gain(prices, period \\ 14)

  def average_gain(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def average_gain(prices, period) when is_list(prices) and length(prices) <= period, do: nil

  def average_gain(prices, period) when is_list(prices) do
    case wilder_averages(prices, period) do
      {gain_avg, _loss_avg} -> gain_avg
    end
  end

  @doc """
  Wilder-smoothed average loss over the `period` newest price changes.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.RSI.average_loss([6, 1, 4, 2, 5, 3], 3) |> Float.round(4)
      1.7037
  """
  @spec average_loss(list(number), pos_integer) :: float | nil
  def average_loss(prices, period \\ 14)

  def average_loss(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def average_loss(prices, period) when is_list(prices) and length(prices) <= period, do: nil

  def average_loss(prices, period) when is_list(prices) do
    case wilder_averages(prices, period) do
      {_gain_avg, loss_avg} -> loss_avg
    end
  end

  @doc """
  Sum of gains across consecutive prices, oldest first.

  ## Examples

      iex> TAlib.Indicators.RSI.gain([0, 10, 20, 30])
      30
  """
  @spec gain(list(number)) :: number
  def gain([]), do: 0
  def gain([_single]), do: 0

  def gain(prices) when is_list(prices),
    do: window_changes(prices) |> Enum.reduce(0, fn change, acc -> acc + max(change, 0) end)

  @doc """
  Sum of losses across consecutive prices, oldest first.

  ## Examples

      iex> TAlib.Indicators.RSI.loss([40, 30, 20, 10])
      30
  """
  @spec loss(list(number)) :: number
  def loss([]), do: 0
  def loss([_single]), do: 0

  def loss(prices) when is_list(prices),
    do: window_changes(prices) |> Enum.reduce(0, fn change, acc -> acc + max(-change, 0) end)

  # Consecutive price changes, chronological: b - a for each adjacent
  # pair, built by one walk instead of a two-element window per bar.
  defp window_changes([first | rest]), do: changes_walk(rest, first, [])

  defp changes_walk([], _prev, acc), do: Enum.reverse(acc)
  defp changes_walk([b | rest], a, acc), do: changes_walk(rest, b, [b - a | acc])

  # Wilder-smoothed gain/loss averages for the latest point.
  defp wilder_averages(prices, period) do
    changes = window_changes(prices)
    gains = Enum.map(changes, &max(&1, 0))
    losses = Enum.map(changes, &max(-&1, 0))

    gain_avg = Enum.sum(Enum.take(gains, period)) / period
    loss_avg = Enum.sum(Enum.take(losses, period)) / period

    Enum.zip(Enum.drop(gains, period), Enum.drop(losses, period))
    |> Enum.reduce({gain_avg, loss_avg}, fn {gain, loss}, {g, l} ->
      {(g * (period - 1) + gain) / period, (l * (period - 1) + loss) / period}
    end)
  end

  defp rsi_from_sums(gain_avg, loss_avg) do
    cond do
      gain_avg == 0 and loss_avg == 0 -> nil
      loss_avg == 0 -> 100.0
      true -> 100.0 - 100.0 / (1.0 + gain_avg / loss_avg)
    end
  end

  # ------------------------------------------------------------------
  # Streaming: O(1) per price. `init` replays the history through the
  # same Wilder walk `rsi_list/2` runs, so its series equals the batch
  # series exactly and `next/2` continues it bit for bit. A window with
  # no movement at all makes RSI undefined — `next/2` returns `nil`
  # there, like the batch series does.
  # ------------------------------------------------------------------

  defmodule State do
    @moduledoc false
    @type t :: %__MODULE__{}
    defstruct [:period, :prev, :gains, :losses, :gain_avg, :loss_avg]
  end

  @doc """
  Warm up streaming RSI state from `history`.

  Returns `{state, values}` with `values` the full RSI series of
  `history` (identical to `rsi_list/2`), and `state` ready to continue
  it one price at a time in O(1) via `next/2`. History needs more than
  `period` prices (the first `period` changes form the seed).

  ## Examples

      iex> {state, values} = TAlib.Indicators.RSI.init([1, 2, 3, 4, 5], 3)
      iex> values
      [nil, nil, nil, 100.0, 100.0]
      iex> {_state, 100.0} = TAlib.Indicators.RSI.next(state, 6)
  """
  @spec init(list(number), pos_integer) :: {State.t(), list(float | nil)}
  def init(prices, period \\ 14)

  def init(_prices, period) when not is_valid_period(period), do: TAlib.invalid_period!(period)

  def init(prices, period) when is_list(prices) do
    if length(prices) <= period,
      do: raise(ArgumentError, "init needs more than period (#{period}) prices")

    state = %State{
      period: period,
      prev: nil,
      gains: Roll.sum_new(period),
      losses: Roll.sum_new(period),
      gain_avg: nil,
      loss_avg: nil
    }

    Roll.replay(prices, state, &next/2)
  end

  @doc """
  Advance streaming RSI state by one price, in O(1).

      iex> {state, _} = TAlib.Indicators.RSI.init([1, 2, 3, 4, 5], 3)
      iex> {_state, value} = TAlib.Indicators.RSI.next(state, 6)
      iex> value
      100.0
  """
  @spec next(State.t(), number) :: {State.t(), float | nil}
  def next(%State{prev: nil} = state, price), do: {%{state | prev: price}, nil}

  def next(
        %State{period: period, prev: prev, gains: gains, losses: losses, gain_avg: nil} = state,
        price
      ) do
    change = price - prev
    {gains, gain_sum} = Roll.sum_push(gains, max(change, 0))
    {losses, loss_sum} = Roll.sum_push(losses, max(-change, 0))
    state = %{state | prev: price, gains: gains, losses: losses}

    if gain_sum do
      gain_avg = gain_sum / period
      loss_avg = loss_sum / period
      {%{state | gain_avg: gain_avg, loss_avg: loss_avg}, rsi_from_sums(gain_avg, loss_avg)}
    else
      {state, nil}
    end
  end

  def next(
        %State{period: period, prev: prev, gain_avg: gain_avg, loss_avg: loss_avg} = state,
        price
      ) do
    change = price - prev
    gain = max(change, 0)
    loss = max(-change, 0)
    gain_avg = (gain_avg * (period - 1) + gain) / period
    loss_avg = (loss_avg * (period - 1) + loss) / period

    {%{state | prev: price, gain_avg: gain_avg, loss_avg: loss_avg},
     rsi_from_sums(gain_avg, loss_avg)}
  end
end
