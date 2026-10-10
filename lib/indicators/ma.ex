defmodule TAlib.Indicators.MA do
  @moduledoc """
  Moving average indicator [Wikipedia](https://en.wikipedia.org/wiki/Moving_average).

  Calculates SMA, WMA, EMA and CMA, plus incremental `update_*` helpers for
  maintaining a moving average as new prices arrive.

  See `TAlib` for the input conventions: the scalar and `update_*` functions
  take prices newest first, the `*_list` functions take prices oldest first.
  All functions return `nil` when there is not enough data.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate the Simple Moving Average of the `period` newest prices.

  ## Parameters

    - prices: list of prices, newest first.
    - period: lookback window, a positive integer.

  ## Examples

      iex> TAlib.Indicators.MA.sma([1, 2, 3, 4], 3)
      2.0
  """
  @spec sma(list(number), pos_integer) :: float | nil
  def sma(prices, period \\ 50)

  def sma(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def sma(prices, period) when is_list(prices) and length(prices) < period, do: nil

  def sma(prices, period) when is_list(prices),
    do: Enum.sum(Enum.take(prices, period)) / period

  @doc """
  Calculate the full SMA series.

  Returns a list aligned with `prices`: the first `period - 1` entries are
  `nil`, and every later entry is the simple moving average of the window
  ending at that point.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer.

  ## Examples

      iex> TAlib.Indicators.MA.sma_list([1, 2, 3, 4, 5], 3)
      [nil, nil, 2.0, 3.0, 4.0]
  """
  @spec sma_list(list(number), pos_integer) :: list(float | nil)
  def sma_list(prices, period \\ 50)

  def sma_list(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def sma_list(prices, period) when is_list(prices),
    do: map_series(prices, &sma(&1, period))

  @doc """
  Update a Simple Moving Average when a new price arrives.

  `prices` (newest first) must **not** include `new_value`; the current
  window is the `period` newest prices, and the value leaving it is
  `Enum.at(prices, period - 1)`.

  ## Parameters

    - prices: list of prices, newest first, without `new_value`.
    - current_sma: the previously calculated SMA.
    - new_value: the new price.
    - period: lookback window, a positive integer.

  ## Examples

      iex> TAlib.Indicators.MA.update_sma([5, 4, 3, 2, 1], 4.5, 3, 2)
      4.0
  """
  @spec update_sma(list(number), number, number, pos_integer) :: float | nil
  def update_sma(prices, current_sma, new_value, period \\ 50)

  def update_sma(_prices, _current_sma, _new_value, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def update_sma(prices, _current_sma, _new_value, period)
      when is_list(prices) and length(prices) < period,
      do: nil

  def update_sma(prices, current_sma, new_value, period) when is_list(prices) do
    value_to_remove = Enum.at(prices, period - 1)
    current_sma + (new_value - value_to_remove) / period
  end

  @doc """
  Calculate the Cumulative (unweighted) Moving Average: the arithmetic mean
  of **all** given prices. Unlike the other functions it takes no window;
  use `update_cma/3` to maintain it incrementally.

  ## Parameters

    - prices: list of prices (the mean is order-independent).

  ## Examples

      iex> TAlib.Indicators.MA.cma([0, 1, 2, 3])
      1.5
  """
  @spec cma(list(number)) :: float | nil
  def cma([]), do: nil

  def cma(prices) when is_list(prices), do: Enum.sum(prices) / length(prices)

  @doc """
  Update a Cumulative Moving Average when a new price arrives.

  `period` is the number of prices already averaged into `current_cma`.

  ## Parameters

    - current_cma: the previously calculated CMA.
    - new_value: the new price.
    - period: how many prices `current_cma` covers, a positive integer.

  ## Examples

      iex> TAlib.Indicators.MA.update_cma(44.45, 44.0, 4)
      44.36
  """
  @spec update_cma(number, number, pos_integer) :: float
  def update_cma(current_cma, new_value, period)

  def update_cma(_current_cma, _new_value, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def update_cma(current_cma, new_value, period),
    do: current_cma + (new_value - current_cma) / (period + 1)

  @doc """
  Calculate the Linear Weighted Moving Average of the `period` newest
  prices. The newest price gets the weight `period`, the oldest price in
  the window gets 1.

  ## Parameters

    - prices: list of prices, newest first.
    - period: lookback window, a positive integer.

  ## Examples

      iex> TAlib.Indicators.MA.wma([3, 2, 1, 0], 3) |> Float.round(4)
      2.3333
  """
  @spec wma(list(number), pos_integer) :: float | nil
  def wma(prices, period \\ 50)

  def wma(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def wma(prices, period) when is_list(prices) and length(prices) < period, do: nil

  def wma(prices, period) when is_list(prices) do
    weighted_total =
      prices
      |> Enum.take(period)
      |> Enum.with_index()
      |> Enum.reduce(0, fn {price, idx}, acc -> acc + price * (period - idx) end)

    weighted_total / (period * (period + 1) / 2)
  end

  @doc """
  Calculate the Exponential Moving Average.

  The series is seeded with the SMA of the oldest `period` prices, then
  walked forward with `multiplier = 2 / (period + 1)`.

  ## Parameters

    - prices: list of prices, newest first.
    - period: lookback window, a positive integer.

  ## Examples

      iex> TAlib.Indicators.MA.ema([4, 3, 2, 1], 2)
      3.5
  """
  @spec ema(list(number), pos_integer) :: float | nil
  def ema(prices, period \\ 50)

  def ema(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def ema(prices, period) when is_list(prices) and length(prices) < period, do: nil

  def ema(prices, period) when is_list(prices) and length(prices) == period,
    do: sma(prices, period)

  def ema(prices, period) when is_list(prices) do
    multiplier = 2 / (period + 1)
    last_ema = ema(tl(prices), period)
    last_ema + multiplier * (hd(prices) - last_ema)
  end

  @doc """
  Calculate the full EMA series, seeded at the SMA of the oldest `period`
  prices (the same series `ema/2` walks backwards from).

  Returns a list aligned with `prices`: the first `period - 1` entries are
  `nil`, and every later entry is the EMA as of that point.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer.

  ## Examples

      iex> TAlib.Indicators.MA.ema_list([1, 2, 3, 4, 5], 2)
      [nil, 1.5, 2.5, 3.5, 4.5]
  """
  @spec ema_list(list(number), pos_integer) :: list(float | nil)
  def ema_list(prices, period \\ 50)

  def ema_list(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def ema_list(prices, period) when is_list(prices),
    do: map_series(prices, &ema(&1, period))

  @doc """
  Update an Exponential Moving Average when a new price arrives.

  ## Parameters

    - current_ema: the previously calculated EMA.
    - new_value: the new price.
    - period: EMA period, a positive integer.

  ## Examples

      iex> TAlib.Indicators.MA.update_ema(1306.72, 1300, 50) |> Float.round(4)
      1306.4565
  """
  @spec update_ema(number, number, pos_integer) :: float
  def update_ema(current_ema, new_value, period)

  def update_ema(_current_ema, _new_value, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def update_ema(current_ema, new_value, period) do
    multiplier = 2 / (period + 1)
    current_ema + multiplier * (new_value - current_ema)
  end

  # Applies `fun` to every suffix of the reversed (newest-first) list.
  # Dropping the newest price at each step yields the value at every point
  # of the chronological series, and consing onto the accumulator keeps the
  # result in chronological order without re-reversing.
  defp map_series(prices, fun) do
    prices
    |> Enum.reverse()
    |> walk_series([], fun)
  end

  defp walk_series([], acc, _fun), do: acc

  defp walk_series(prices, acc, fun), do: walk_series(tl(prices), [fun.(prices) | acc], fun)
end
