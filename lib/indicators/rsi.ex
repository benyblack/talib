defmodule TAlib.Indicators.RSI do
  @moduledoc """
  Relative Strength Index [Wikipedia](https://en.wikipedia.org/wiki/Relative_strength_index).

  Gain and loss averages are simple (arithmetic) means over the lookback
  window ("Cutler's RSI"). Note that TA-Lib and most charting platforms use
  Wilder's smoothed averages, which converge to somewhat different values
  for the same data.

  See `TAlib` for the input conventions: `rsi/2`, `average_gain/2` and
  `average_loss/2` take prices newest first, `rsi_list/3` takes them oldest
  first. `nil` is returned when there is not enough data or the window has
  no movement (RSI is undefined).
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate RSI for each point of a price series.

  Returns a list aligned with `data`: the first `period` entries are `nil`,
  and every later entry is the RSI of the window ending at that point.

  ## Parameters

    - data: list of prices, oldest first (unless `top_is_first`).
    - period: lookback window, a positive integer (default 14).
    - top_is_first: `true` if the newest price is the head of the list.

  ## Examples

      iex> TAlib.Indicators.RSI.rsi_list([1, 2, 3, 4, 5], 3)
      [nil, nil, nil, 100.0, 100.0]
  """
  @spec rsi_list(list(number), pos_integer, boolean) :: list(float | nil)
  def rsi_list(data, period \\ 14, top_is_first \\ false)

  def rsi_list(_data, period, _top_is_first) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def rsi_list([], _period, _top_is_first), do: []

  def rsi_list(data, period, false), do: Enum.reverse(rsi_list(Enum.reverse(data), period, true))

  def rsi_list(data, period, true) when length(data) == 1, do: [rsi(data, period)]

  def rsi_list(data, period, true) do
    [rsi(data, period) | rsi_list(tl(data), period, true)]
  end

  @doc """
  Calculate RSI over the `period` newest price changes.

  ## Parameters

    - prices: list of prices, newest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.RSI.rsi([6, 5, 4, 3, 2, 1], 3)
      100.0

      iex> TAlib.Indicators.RSI.rsi([3, 5, 2, 4, 1, 6], 3) |> Float.round(4)
      42.8571
  """
  @spec rsi(list(number), pos_integer) :: float | nil
  def rsi(prices, period \\ 14)

  def rsi(_prices, period) when not is_valid_period(period), do: TAlib.invalid_period!(period)

  def rsi([], _period), do: nil

  def rsi(prices, period) when is_list(prices) and length(prices) <= period, do: nil

  def rsi(prices, period) when is_list(prices) do
    avg_gain = average_gain(prices, period)
    avg_loss = average_loss(prices, period)

    cond do
      avg_gain == 0 and avg_loss == 0 -> nil
      avg_loss == 0 -> 100.0
      true -> 100.0 - 100.0 / (1.0 + avg_gain / avg_loss)
    end
  end

  @doc """
  Average gain per period over the `period` newest price changes.

  ## Parameters

    - prices: list of prices, newest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.RSI.average_gain([30, 20, 10, 0], 3)
      10.0
  """
  @spec average_gain(list(number), pos_integer) :: float
  def average_gain(prices, period \\ 14)

  def average_gain(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def average_gain([], _period), do: 0.0

  def average_gain([_single], _period), do: 0.0

  def average_gain(prices, period) when is_list(prices) do
    price_history = Enum.take(prices, period + 1)
    gain(price_history) / (length(price_history) - 1)
  end

  @doc """
  Average loss per period over the `period` newest price changes.

  ## Parameters

    - prices: list of prices, newest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.RSI.average_loss([10, 20, 30, 40], 3)
      10.0
  """
  @spec average_loss(list(number), pos_integer) :: float
  def average_loss(prices, period \\ 14)

  def average_loss(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def average_loss([], _period), do: 0.0

  def average_loss([_single], _period), do: 0.0

  def average_loss(prices, period) when is_list(prices) do
    price_history = Enum.take(prices, period + 1)
    loss(price_history) / (length(price_history) - 1)
  end

  @doc """
  Sum of gains across consecutive prices (newest first).

  ## Examples

      iex> TAlib.Indicators.RSI.gain([30, 20, 10, 0])
      30
  """
  @spec gain(list(number)) :: number
  def gain([]), do: 0
  def gain([_single]), do: 0

  def gain([head | tail]) when hd(tail) >= head, do: gain(tail)

  def gain([head | tail]) when hd(tail) < head, do: head - hd(tail) + gain(tail)

  @doc """
  Sum of losses across consecutive prices (newest first).

  ## Examples

      iex> TAlib.Indicators.RSI.loss([1, 2, 3, 4])
      3
  """
  @spec loss(list(number)) :: number
  def loss([]), do: 0
  def loss([_single]), do: 0

  def loss([head | tail]) when hd(tail) <= head, do: loss(tail)

  def loss([head | tail]) when hd(tail) > head, do: hd(tail) - head + loss(tail)
end
