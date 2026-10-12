defmodule TAlib.Indicators.RSI do
  @moduledoc """
  Relative Strength Index [Wikipedia](https://en.wikipedia.org/wiki/Relative_strength_index).

  Gain and loss averages are simple (arithmetic) means over the lookback
  window ("Cutler's RSI"). Note that TA-Lib and most charting platforms use
  Wilder's smoothed averages, which converge to somewhat different values
  for the same data.

  See `TAlib` for the input conventions: prices are always given in
  chronological order, oldest first, and series are returned aligned with
  the input. `nil` is returned when there is not enough data or the window
  has no movement (RSI is undefined).
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate RSI for each point of a price series in a single pass
  (sliding gain/loss window sums).

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

    window = Enum.take(changes, period)
    gain_sum = window |> Enum.map(&max(&1, 0)) |> Enum.sum()
    loss_sum = window |> Enum.map(&max(-&1, 0)) |> Enum.sum()
    ahead = Enum.drop(changes, period)

    List.duplicate(nil, period) ++
      [rsi_from_sums(gain_sum, loss_sum) | slide_rsi(changes, ahead, gain_sum, loss_sum, [])]
  end

  @doc """
  Calculate RSI over the `period` newest price changes.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.RSI.rsi([1, 2, 3, 4, 5, 6], 3)
      100.0

      iex> TAlib.Indicators.RSI.rsi([6, 1, 4, 2, 5, 3], 3) |> Float.round(4)
      42.8571
  """
  @spec rsi(list(number), pos_integer) :: float | nil
  def rsi(prices, period \\ 14)

  def rsi(_prices, period) when not is_valid_period(period), do: TAlib.invalid_period!(period)

  def rsi([], _period), do: nil

  def rsi(prices, period) when is_list(prices) and length(prices) <= period, do: nil

  def rsi(prices, period) when is_list(prices) do
    changes = prices |> Enum.take(-(period + 1)) |> window_changes()
    gain_sum = changes |> Enum.map(&max(&1, 0)) |> Enum.sum()
    loss_sum = changes |> Enum.map(&max(-&1, 0)) |> Enum.sum()
    rsi_from_sums(gain_sum, loss_sum)
  end

  @doc """
  Average gain per period over the `period` newest price changes.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.RSI.average_gain([0, 10, 20, 30], 3)
      10.0
  """
  @spec average_gain(list(number), pos_integer) :: float
  def average_gain(prices, period \\ 14)

  def average_gain(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def average_gain([], _period), do: 0.0

  def average_gain([_single], _period), do: 0.0

  def average_gain(prices, period) when is_list(prices) do
    changes = prices |> Enum.take(-(period + 1)) |> window_changes()
    Enum.sum(Enum.map(changes, &max(&1, 0))) / length(changes)
  end

  @doc """
  Average loss per period over the `period` newest price changes.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.RSI.average_loss([40, 30, 20, 10], 3)
      10.0
  """
  @spec average_loss(list(number), pos_integer) :: float
  def average_loss(prices, period \\ 14)

  def average_loss(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def average_loss([], _period), do: 0.0

  def average_loss([_single], _period), do: 0.0

  def average_loss(prices, period) when is_list(prices) do
    changes = prices |> Enum.take(-(period + 1)) |> window_changes()
    Enum.sum(Enum.map(changes, &max(-&1, 0))) / length(changes)
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

  # Consecutive price changes, chronological: b - a for each adjacent pair.
  defp window_changes(prices),
    do: prices |> Enum.chunk_every(2, 1, :discard) |> Enum.map(fn [a, b] -> b - a end)

  defp rsi_from_sums(gain_sum, loss_sum) do
    cond do
      gain_sum == 0 and loss_sum == 0 -> nil
      loss_sum == 0 -> 100.0
      true -> 100.0 - 100.0 / (1.0 + gain_sum / loss_sum)
    end
  end

  defp slide_rsi(_older, [], _gain_sum, _loss_sum, acc), do: Enum.reverse(acc)

  defp slide_rsi([leaving | older], [adding | ahead], gain_sum, loss_sum, acc) do
    new_gain_sum = gain_sum - max(leaving, 0) + max(adding, 0)
    new_loss_sum = loss_sum - max(-leaving, 0) + max(-adding, 0)

    slide_rsi(older, ahead, new_gain_sum, new_loss_sum, [
      rsi_from_sums(new_gain_sum, new_loss_sum) | acc
    ])
  end
end
