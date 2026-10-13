defmodule TAlib.Indicators.MA do
  alias TAlib.Indicators.Roll
  alias TAlib.Indicators.Window

  @moduledoc """
  Moving average indicator [Wikipedia](https://en.wikipedia.org/wiki/Moving_average).

  Calculates SMA, WMA, EMA and CMA, plus streaming `*_init`/`*_next`
  state for maintaining a moving average in O(1) as new prices arrive
  (and the older incremental `update_*` helpers).

  See `TAlib` for the input conventions: prices are always given in
  chronological order, oldest first. Series functions return results aligned
  with the input, the first `period - 1` entries being `nil`. All functions
  return `nil` when there is not enough data.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate the Simple Moving Average of the `period` newest prices.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer.

  ## Examples

      iex> TAlib.Indicators.MA.sma([1, 2, 3, 4], 3)
      3.0
  """
  @spec sma(list(number), pos_integer) :: float | nil
  def sma(prices, period \\ 50)

  def sma(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def sma(prices, period) when is_list(prices) and length(prices) < period, do: nil

  def sma(prices, period) when is_list(prices),
    do: Enum.sum(Enum.take(prices, -period)) / period

  @doc """
  Calculate the full SMA series in a single pass (sliding window sum).

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

  def sma_list(prices, period) when is_list(prices) and length(prices) < period,
    do: List.duplicate(nil, length(prices))

  def sma_list(prices, period) when is_list(prices) do
    initial = Enum.sum(Enum.take(prices, period))
    ahead = Enum.drop(prices, period)

    List.duplicate(nil, period - 1) ++
      [initial / period | slide_sma(prices, ahead, initial, period, [])]
  end

  @doc """
  Update a Simple Moving Average when a new price arrives.

  `prices` (oldest first) must **not** include `new_value`; the current
  window is the `period` newest prices, and the value leaving it is
  `Enum.at(prices, length(prices) - period)`.

  ## Parameters

    - prices: list of prices, oldest first, without `new_value`.
    - current_sma: the previously calculated SMA.
    - new_value: the new price.
    - period: lookback window, a positive integer.

  ## Examples

      iex> TAlib.Indicators.MA.update_sma([1, 2, 3, 4, 5], 4.5, 3, 2)
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
    value_to_remove = Enum.at(prices, length(prices) - period)
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
  Calculate the full CMA series: the running mean over all prices seen so
  far at every point.

  ## Parameters

    - prices: list of prices, oldest first.

  ## Examples

      iex> TAlib.Indicators.MA.cma_list([1, 2, 3])
      [1.0, 1.5, 2.0]
  """
  @spec cma_list(list(number)) :: list(float)
  def cma_list([]), do: []

  def cma_list(prices) when is_list(prices) do
    prices
    |> Enum.scan(fn price, acc -> acc + price end)
    |> Enum.with_index()
    |> Enum.map(fn {sum, index} -> sum / (index + 1) end)
  end

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

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer.

  ## Examples

      iex> TAlib.Indicators.MA.wma([1, 2, 3, 4], 3)
      3.3333333333333335
  """
  @spec wma(list(number), pos_integer) :: float | nil
  def wma(prices, period \\ 50)

  def wma(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def wma(prices, period) when is_list(prices) and length(prices) < period, do: nil

  def wma(prices, period) when is_list(prices) do
    weighted_total =
      prices
      |> Enum.take(-period)
      |> Enum.with_index()
      |> Enum.reduce(0, fn {price, idx}, acc -> acc + price * (idx + 1) end)

    weighted_total / (period * (period + 1) / 2)
  end

  @doc """
  Calculate the full WMA series in a single pass (sliding weighted and
  plain window sums).

  Returns a list aligned with `prices`: the first `period - 1` entries are
  `nil`, and every later entry is the weighted moving average of the window
  ending at that point.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer.

  ## Examples

      iex> TAlib.Indicators.MA.wma_list([1, 2, 3, 4, 5], 3)
      [nil, nil, 2.3333333333333335, 3.3333333333333335, 4.333333333333333]
  """
  @spec wma_list(list(number), pos_integer) :: list(float | nil)
  def wma_list(prices, period \\ 50)

  def wma_list(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def wma_list(prices, period) when is_list(prices) and length(prices) < period,
    do: List.duplicate(nil, length(prices))

  def wma_list(prices, period) when is_list(prices) do
    window = Enum.take(prices, period)
    denominator = period * (period + 1) / 2

    initial_weighted =
      window
      |> Enum.with_index()
      |> Enum.reduce(0, fn {price, idx}, acc -> acc + price * (idx + 1) end)

    initial_sum = Enum.sum(window)
    ahead = Enum.drop(prices, period)

    List.duplicate(nil, period - 1) ++
      [
        initial_weighted / denominator
        | slide_wma(prices, ahead, initial_weighted, initial_sum, period, denominator, [])
      ]
  end

  @doc """
  Calculate the Exponential Moving Average.

  The series is seeded with the SMA of the oldest `period` prices, then
  walked forward with `multiplier = 2 / (period + 1)`.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer.

  ## Examples

      iex> TAlib.Indicators.MA.ema([1, 2, 3, 4], 2)
      3.5
  """
  @spec ema(list(number), pos_integer) :: float | nil
  def ema(prices, period \\ 50)

  def ema(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def ema(prices, period) when is_list(prices) and length(prices) < period, do: nil

  def ema(prices, period) when is_list(prices) do
    seed = Enum.sum(Enum.take(prices, period)) / period
    multiplier = 2 / (period + 1)

    Enum.reduce(Enum.drop(prices, period), seed, fn price, acc ->
      acc + multiplier * (price - acc)
    end)
  end

  @doc """
  Calculate the full EMA series in a single forward pass, seeded at the SMA
  of the oldest `period` prices.

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

  def ema_list(prices, period) when is_list(prices) and length(prices) < period,
    do: List.duplicate(nil, length(prices))

  def ema_list(prices, period) when is_list(prices) do
    seed = Enum.sum(Enum.take(prices, period)) / period
    multiplier = 2 / (period + 1)

    {emas, _last} =
      Enum.reduce(Enum.drop(prices, period), {[seed], seed}, fn price, {acc, prev} ->
        value = prev + multiplier * (price - prev)
        {[value | acc], value}
      end)

    List.duplicate(nil, period - 1) ++ Enum.reverse(emas)
  end

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

  @doc """
  Calculate Wilder's smoothed Moving Average (RMA), used by ATR, ADX and
  friends: seeded with the SMA of the oldest `period` prices, then
  `rma = (prev * (period - 1) + price) / period`.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer.

  ## Examples

      iex> TAlib.Indicators.MA.rma([1, 2, 3, 4, 5], 3) |> Float.round(4)
      3.4444
  """
  @spec rma(list(number), pos_integer) :: float | nil
  def rma(prices, period \\ 50)

  def rma(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def rma(prices, period) when is_list(prices) and length(prices) < period, do: nil

  def rma(prices, period) when is_list(prices) do
    seed = Enum.sum(Enum.take(prices, period)) / period

    Enum.reduce(Enum.drop(prices, period), seed, fn price, acc ->
      (acc * (period - 1) + price) / period
    end)
  end

  @doc """
  Calculate the full RMA series in a single forward pass.

  Returns a list aligned with `prices`: the first `period - 1` entries are
  `nil`, and every later entry is the Wilder-smoothed average as of that
  point.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer.

  ## Examples

      iex> TAlib.Indicators.MA.rma_list([1, 2, 3, 4, 5], 3)
      [nil, nil, 2.0, 2.6666666666666665, 3.444444444444444]
  """
  @spec rma_list(list(number), pos_integer) :: list(float | nil)
  def rma_list(prices, period \\ 50)

  def rma_list(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def rma_list(prices, period) when is_list(prices) and length(prices) < period,
    do: List.duplicate(nil, length(prices))

  def rma_list(prices, period) when is_list(prices) do
    seed = Enum.sum(Enum.take(prices, period)) / period

    {rmas, _last} =
      Enum.reduce(Enum.drop(prices, period), {[seed], seed}, fn price, {acc, prev} ->
        value = (prev * (period - 1) + price) / period
        {[value | acc], value}
      end)

    List.duplicate(nil, period - 1) ++ Enum.reverse(rmas)
  end

  @doc """
  Calculate the Double Exponential Moving Average: `2 * EMA - EMA(EMA)`.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer (default 30).

  ## Examples

      iex> TAlib.Indicators.MA.dema([1, 2, 3, 4, 5, 6, 7, 8], 2)
      8.0
  """
  @spec dema(list(number), pos_integer) :: float | nil
  def dema(prices, period \\ 30)

  def dema(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def dema(prices, period) when is_list(prices) and length(prices) < 2 * period - 1,
    do: nil

  def dema(prices, period) when is_list(prices),
    do: prices |> dema_series(period) |> List.last()

  @doc """
  Calculate the full DEMA series (`2 * EMA - EMA(EMA)`).

      iex> TAlib.Indicators.MA.dema_list([1, 2, 3, 4, 5, 6, 7, 8], 2)
      [nil, nil, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
  """
  @spec dema_list(list(number), pos_integer) :: list(float | nil)
  def dema_list(prices, period \\ 30)

  def dema_list(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def dema_list(prices, period) when is_list(prices) and length(prices) < 2 * period - 1,
    do: List.duplicate(nil, length(prices))

  def dema_list(prices, period) when is_list(prices), do: dema_series(prices, period)

  @doc """
  Calculate the Triple Exponential Moving Average:
  `3 * EMA - 3 * EMA(EMA) + EMA(EMA(EMA))`.

      iex> TAlib.Indicators.MA.tema([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 2) |> Float.round(4)
      10.0
  """
  @spec tema(list(number), pos_integer) :: float | nil
  def tema(prices, period \\ 30)

  def tema(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def tema(prices, period) when is_list(prices) and length(prices) < 3 * period - 2,
    do: nil

  def tema(prices, period) when is_list(prices),
    do: prices |> tema_series(period) |> List.last()

  @doc """
  Calculate the full TEMA series.

      iex> TAlib.Indicators.MA.tema_list([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 2)
      [nil, nil, nil, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
  """
  @spec tema_list(list(number), pos_integer) :: list(float | nil)
  def tema_list(prices, period \\ 30)

  def tema_list(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def tema_list(prices, period) when is_list(prices) and length(prices) < 3 * period - 2,
    do: List.duplicate(nil, length(prices))

  def tema_list(prices, period) when is_list(prices), do: tema_series(prices, period)

  @doc """
  Calculate the Triangular Moving Average: an SMA applied twice, over the
  half (odd period) or half/half-plus-one (even period) windows.

      iex> TAlib.Indicators.MA.trima([1, 2, 3, 4, 5, 6, 7], 5)
      5.0
  """
  @spec trima(list(number), pos_integer) :: float | nil
  def trima(prices, period \\ 30)

  def trima(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def trima(prices, period) when is_list(prices) and length(prices) < period, do: nil

  def trima(prices, period) when is_list(prices), do: List.last(trima_series(prices, period))

  @doc """
  Calculate the full TRIMA series.

      iex> TAlib.Indicators.MA.trima_list([1, 2, 3, 4, 5, 6, 7], 5)
      [nil, nil, nil, nil, 3.0, 4.0, 5.0]
  """
  @spec trima_list(list(number), pos_integer) :: list(float | nil)
  def trima_list(prices, period \\ 30)

  def trima_list(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def trima_list(prices, period) when is_list(prices) and length(prices) < period,
    do: List.duplicate(nil, length(prices))

  def trima_list(prices, period) when is_list(prices), do: trima_series(prices, period)

  @doc """
  Calculate Kaufman's Adaptive Moving Average: an exponential average
  whose smoothing constant adapts to the efficiency ratio
  (net change over path length) of the last `period` prices.

  The smoothing constants are fixed like TA-Lib's (fastest 2/3,
  slowest 2/31) regardless of the period, and at `period` 1 the series
  is the input itself.

      iex> TAlib.Indicators.MA.kama([1, 2, 3, 4, 5, 6, 7, 8], 2) |> Float.round(4)
      6.7868
  """
  @spec kama(list(number), pos_integer) :: float | nil
  def kama(prices, period \\ 30)

  def kama(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def kama(prices, period) when is_list(prices) and period > 1 and length(prices) < period + 1,
    do: nil

  def kama(prices, period) when is_list(prices), do: List.last(kama_series(prices, period))

  @doc """
  Calculate the full KAMA series.

      iex> TAlib.Indicators.MA.kama_list([1, 2, 3, 4, 5, 6, 7, 8], 2) |> Enum.map(fn
      ...>   nil -> nil
      ...>   x -> Float.round(x * 1.0, 4)
      ...> end)
      [nil, nil, 2.4444, 3.1358, 3.9643, 4.8691, 5.8162, 6.7868]
  """
  @spec kama_list(list(number), pos_integer) :: list(number | nil)
  def kama_list(prices, period \\ 30)

  def kama_list(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def kama_list(prices, period)
      when is_list(prices) and period > 1 and length(prices) < period + 1,
      do: List.duplicate(nil, length(prices))

  def kama_list(prices, period) when is_list(prices), do: kama_series(prices, period)

  @doc """
  Calculate Tim Tillson's T3 moving average: six chained EMAs combined
  with the given volume factor.

      iex> TAlib.Indicators.MA.t3(Enum.to_list(1..14), 2) |> Float.round(4)
      13.55
  """
  @spec t3(list(number), pos_integer, number) :: float | nil
  def t3(prices, period \\ 30, vfactor \\ 0.7)

  def t3(_prices, period, _vfactor) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def t3(_prices, _period, vfactor) when not is_number(vfactor),
    do: raise(ArgumentError, "vfactor must be a number, got: #{inspect(vfactor)}")

  def t3(prices, period, _vfactor) when is_list(prices) and length(prices) < 6 * period - 5,
    do: nil

  def t3(prices, period, vfactor) when is_list(prices),
    do: prices |> t3_series(period, vfactor) |> List.last()

  @doc """
  Calculate the full T3 series.

      iex> TAlib.Indicators.MA.t3_list(Enum.to_list(1..14), 2) |> Enum.count(&is_nil/1)
      6
  """
  @spec t3_list(list(number), pos_integer, number) :: list(float | nil)
  def t3_list(prices, period \\ 30, vfactor \\ 0.7)

  def t3_list(_prices, period, _vfactor) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def t3_list(_prices, _period, vfactor) when not is_number(vfactor),
    do: raise(ArgumentError, "vfactor must be a number, got: #{inspect(vfactor)}")

  def t3_list(prices, period, _vfactor) when is_list(prices) and length(prices) < 6 * period - 5,
    do: List.duplicate(nil, length(prices))

  def t3_list(prices, period, vfactor) when is_list(prices),
    do: t3_series(prices, period, vfactor)

  @doc """
  Calculate the Midpoint of the `period` newest prices:
  `(highest + lowest) / 2`.

      iex> TAlib.Indicators.MA.midpoint([5, 3, 8, 2, 6], 3)
      5.0
  """
  @spec midpoint(list(number), pos_integer) :: float | nil
  def midpoint(prices, period \\ 14)

  def midpoint(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def midpoint(prices, period) when is_list(prices) and length(prices) < period, do: nil

  def midpoint(prices, period) when is_list(prices) do
    window = Enum.take(prices, -period)
    (Enum.max(window) + Enum.min(window)) / 2
  end

  @doc """
  Calculate the full Midpoint series.

      iex> TAlib.Indicators.MA.midpoint_list([5, 3, 8, 2, 6], 3)
      [nil, nil, 5.5, 5.0, 5.0]
  """
  @spec midpoint_list(list(number), pos_integer) :: list(float | nil)
  def midpoint_list(prices, period \\ 14)

  def midpoint_list(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def midpoint_list(prices, period) when is_list(prices) and length(prices) < period,
    do: List.duplicate(nil, length(prices))

  def midpoint_list(prices, period) when is_list(prices) do
    values =
      prices
      |> Window.maxes_mins(period)
      |> Enum.map(fn {highest, lowest} -> (highest + lowest) / 2 end)

    List.duplicate(nil, period - 1) ++ values
  end

  # The EMA values only (no nil padding), from the first defined bar
  # on — the stage inputs of the composite averages; identical values
  # to `ema_list |> Enum.reject(&is_nil/1)` without the padded pass.
  defp ema_values(prices, period) do
    seed = Enum.sum(Enum.take(prices, period)) / period
    multiplier = 2 / (period + 1)

    {reversed, _} =
      Enum.reduce(Enum.drop(prices, period), {[seed], seed}, fn price, {acc, prev} ->
        value = prev + multiplier * (price - prev)
        {[value | acc], value}
      end)

    Enum.reverse(reversed)
  end

  # Each EMA stage lags the previous by `period - 1` bars, so the stages
  # combine tail-aligned: DEMA[i] pairs e1[i] with e2[i] where both sit at
  # input bar i (TA-Lib runs the stages in lockstep the same way).
  defp dema_series(prices, period) do
    e1 = ema_values(prices, period)
    e2 = ema_values(e1, period)

    values =
      Enum.zip(Enum.drop(e1, period - 1), e2) |> Enum.map(fn {a, b} -> 2 * a - b end)

    List.duplicate(nil, 2 * (period - 1)) ++ values
  end

  defp tema_series(prices, period) do
    e1 = ema_values(prices, period)
    e2 = ema_values(e1, period)
    e3 = ema_values(e2, period)

    values =
      [Enum.drop(e1, 2 * (period - 1)), Enum.drop(e2, period - 1), e3]
      |> Enum.zip()
      |> Enum.map(fn {a, b, c} -> 3 * a - 3 * b + c end)

    List.duplicate(nil, 3 * (period - 1)) ++ values
  end

  defp trima_series(prices, period) do
    {first, second} =
      if rem(period, 2) == 1 do
        half = div(period + 1, 2)
        {half, half}
      else
        {div(period, 2), div(period, 2) + 1}
      end

    values =
      prices
      |> sma_list(first)
      |> Enum.reject(&is_nil/1)
      |> sma_list(second)
      |> Enum.reject(&is_nil/1)

    List.duplicate(nil, period - 1) ++ values
  end

  defp t3_series(prices, period, vfactor) do
    emas =
      Enum.reduce(1..6, [prices], fn _i, [prev | _] = acc ->
        [ema_values(prev, period) | acc]
      end)
      |> Enum.reverse()
      |> Enum.drop(1)

    # Coefficients exactly as TA-Lib builds them (same operation order,
    # so the values agree bit for bit).
    temp = vfactor * vfactor
    c1 = 0 - temp * vfactor
    c2 = 3.0 * (temp - c1)
    c3 = (0 - 6.0) * temp - 3.0 * (vfactor - c1)
    c4 = 3.0 * temp + (3.0 * vfactor + 1.0 - c1)

    [e1, e2, e3, e4, e5, e6] = emas

    values =
      [
        Enum.drop(e1, 5 * (period - 1)),
        Enum.drop(e2, 4 * (period - 1)),
        Enum.drop(e3, 3 * (period - 1)),
        Enum.drop(e4, 2 * (period - 1)),
        Enum.drop(e5, period - 1),
        e6
      ]
      |> Enum.zip()
      |> Enum.map(fn {_, _, a, b, c, d} -> c4 * a + (c3 * b + (c1 * d + c2 * c)) end)

    List.duplicate(nil, 6 * (period - 1)) ++ values
  end

  # KAMA mirroring TA-Lib: the smoothing constants are fixed (fastest
  # 2/3, slowest 2/31 — not a function of the period), the efficiency
  # ratio is clamped to 1 (and set to 1 on a flat window), and the
  # volatility sum slides by add-then-subtract like the C code, so the
  # series matches TA-Lib bar for bar.
  @kama_const_max 2.0 / (30.0 + 1.0)
  @kama_const_diff 2.0 / (2.0 + 1.0) - @kama_const_max

  defp kama_series(prices, 1) when is_list(prices), do: Enum.map(prices, &(&1 * 1.0))

  defp kama_series(prices, period) do
    tuple = List.to_tuple(prices)
    size = tuple_size(tuple)

    # The efficiency-ratio sum over the first `period` one-day changes,
    # and the trailing run of exactly-flat changes (TA-Lib resets the
    # sum when a whole window has gone flat to drop rounding residue).
    {sum_roc, null_run, _} =
      Enum.reduce(0..(period - 1), {0.0, 0, 0}, fn i, {sum, nulls, _} ->
        diff = elem(tuple, i) - elem(tuple, i + 1)
        {sum + abs(diff), if(diff == 0.0, do: nulls + 1, else: 0), i + 1}
      end)

    prev = elem(tuple, period - 1)

    {series, _} =
      Enum.reduce(
        period..(size - 1),
        {[], {prev, sum_roc, null_run, elem(tuple, 0), 1}},
        fn i, {acc, {prev_kama, sum_roc, null_run, trailing_value, trailing_idx}} ->
          price = elem(tuple, i)

          {roc, sum_roc, null_run, trailing_value, trailing_idx} =
            if i == period do
              {price - elem(tuple, 0), sum_roc, null_run, elem(tuple, 0), 1}
            else
              leaving = elem(tuple, trailing_idx)
              roc = price - leaving

              sum_roc =
                sum_roc - abs(trailing_value - leaving) + abs(price - elem(tuple, i - 1))

              null_run = if price - elem(tuple, i - 1) == 0.0, do: null_run + 1, else: 0

              {null_run, sum_roc} =
                if null_run >= period, do: {period, 0.0}, else: {null_run, sum_roc}

              {roc, sum_roc, null_run, leaving, trailing_idx + 1}
            end

          efficiency =
            if sum_roc <= 0.0 or sum_roc <= roc,
              do: 1.0,
              else: min(abs(roc / sum_roc), 1.0)

          sc0 = efficiency * @kama_const_diff + @kama_const_max
          sc = sc0 * sc0

          value = (price - prev_kama) * sc + prev_kama

          {[value | acc], {value, sum_roc, null_run, trailing_value, trailing_idx}}
        end
      )

    List.duplicate(nil, period) ++ Enum.reverse(series)
  end

  # Sliding SMA: `older` and `ahead` walk the same list; at each step the
  # head of `older` leaves the window while the head of `ahead` enters it.
  defp slide_sma(_older, [], _sum, _period, acc), do: Enum.reverse(acc)

  defp slide_sma([leaving | older], [adding | ahead], sum, period, acc) do
    new_sum = sum - leaving + adding
    slide_sma(older, ahead, new_sum, period, [new_sum / period | acc])
  end

  # Sliding WMA over the weighted numerator and the plain window sum:
  # when the window slides, every retained weight drops by one and the
  # entering price gets weight `period`, so numerator' = numerator - sum
  # + period * adding.
  defp slide_wma(_older, [], _numerator, _sum, _period, _denominator, acc),
    do: Enum.reverse(acc)

  defp slide_wma([leaving | older], [adding | ahead], numerator, sum, period, denominator, acc) do
    new_numerator = numerator - sum + period * adding
    new_sum = sum - leaving + adding

    slide_wma(older, ahead, new_numerator, new_sum, period, denominator, [
      new_numerator / denominator | acc
    ])
  end

  @doc """
  The generic moving average dispatcher (TA-Lib MA): computes the moving
  average of the given `type` — one of `:sma`, `:ema`, `:wma`, `:dema`,
  `:tema`, `:trima`, `:kama` or `:t3`.

      iex> TAlib.Indicators.MA.ma([1, 2, 3, 4, 5, 6, 7, 8], 4, :ema) |> Float.round(4)
      6.5
  """
  @spec ma(list(number), pos_integer, atom) :: float | nil
  def ma(prices, period, type)

  def ma(prices, period, :sma), do: sma(prices, period)
  def ma(prices, period, :ema), do: ema(prices, period)
  def ma(prices, period, :wma), do: wma(prices, period)
  def ma(prices, period, :dema), do: dema(prices, period)
  def ma(prices, period, :tema), do: tema(prices, period)
  def ma(prices, period, :trima), do: trima(prices, period)
  def ma(prices, period, :kama), do: kama(prices, period)
  def ma(prices, period, :t3), do: t3(prices, period)

  def ma(_prices, _period, type),
    do: raise(ArgumentError, "unknown MA type #{inspect(type)}")

  @doc """
  The variable-period moving average (TA-Lib MAVP): the value at each
  point uses the period given for that point, clamped to
  `[min_period, max_period]` (both defaulting to 2 and 30). Only
  `:sma` and `:ema` types are supported.

      iex> TAlib.Indicators.MA.mavp([1, 2, 3, 4, 5, 6], [2, 2, 2, 2, 2, 2]) |> List.last()
      5.5
  """
  @spec mavp(list(number), list(number), pos_integer, pos_integer, atom) ::
          list(float | nil)
  def mavp(prices, periods, min_period \\ 2, max_period \\ 30, type \\ :sma)

  def mavp(prices, periods, min_period, max_period, type)
      when is_list(prices) and is_list(periods) and is_valid_period(min_period) and
             is_valid_period(max_period) do
    clamped = Enum.map(periods, fn p -> p |> max(min_period) |> min(max_period) |> trunc() end)

    prices
    |> Enum.zip(clamped)
    |> Enum.with_index()
    |> Enum.map(fn {{_price, period}, index} ->
      window = prices |> Enum.take(index + 1) |> Enum.take(-period)

      if length(window) < period do
        nil
      else
        case type do
          :sma -> Enum.sum(window) / period
          :ema -> ema(prices |> Enum.take(index + 1), period)
          type -> raise(ArgumentError, "unknown MAVP type #{inspect(type)}")
        end
      end
    end)
  end

  # ------------------------------------------------------------------
  # Streaming: O(1) per price
  #
  # `*_init` warms the state up by replaying `history` through the same
  # sliding arithmetic the batch walks use (operation for operation), so
  # the returned series equals the batch series exactly and `*_next`
  # continues it bit for bit. The states are opaque — build them with
  # `*_init`, advance them with `*_next`, persist them as-is.
  # ------------------------------------------------------------------

  defmodule EMAState do
    @moduledoc false
    @type t :: %__MODULE__{}
    defstruct [:period, :multiplier, :prev, :seed]
  end

  defmodule RMAState do
    @moduledoc false
    @type t :: %__MODULE__{}
    defstruct [:period, :prev, :seed]
  end

  defmodule WMAState do
    @moduledoc false
    @type t :: %__MODULE__{}
    defstruct [:period, :denominator, :numerator, :count, :sum]
  end

  @doc """
  Warm up streaming SMA state from `history`.

  Returns `{state, values}` with `values` the full SMA series of
  `history` (identical to `sma_list/2`), and `state` ready to continue
  that series one price at a time in O(1) via `sma_next/2`. History
  needs at least `period` prices.

  ## Examples

      iex> {state, values} = TAlib.Indicators.MA.sma_init([1, 2, 3, 4, 5], 3)
      iex> values
      [nil, nil, 2.0, 3.0, 4.0]
      iex> {_state, 5.0} = TAlib.Indicators.MA.sma_next(state, 6)
  """
  @spec sma_init(list(number), pos_integer) :: {Roll.Sum.t(), list(float | nil)}
  def sma_init(prices, period \\ 50)

  def sma_init(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def sma_init(prices, period) when is_list(prices) do
    if length(prices) < period,
      do: raise(ArgumentError, "sma_init needs at least period (#{period}) prices")

    Roll.replay(prices, Roll.sum_new(period), &sma_next/2)
  end

  @doc """
  Advance streaming SMA state by one price, in O(1).

      iex> {state, _} = TAlib.Indicators.MA.sma_init([1, 2, 3, 4, 5], 3)
      iex> {_state, value} = TAlib.Indicators.MA.sma_next(state, 6)
      iex> value
      5.0
  """
  @spec sma_next(Roll.Sum.t(), number) :: {Roll.Sum.t(), float | nil}
  def sma_next(%Roll.Sum{period: period} = state, price) do
    {state, sum} = Roll.sum_push(state, price)
    {state, if(is_nil(sum), do: nil, else: sum / period)}
  end

  @doc """
  Warm up streaming EMA state from `history`: returns `{state, values}`
  (identical to `ema_list/2`) and continues in O(1) via `ema_next/2`.
  History needs at least `period` prices.

      iex> {state, values} = TAlib.Indicators.MA.ema_init([1, 2, 3, 4, 5], 2)
      iex> values
      [nil, 1.5, 2.5, 3.5, 4.5]
      iex> {_state, 5.5} = TAlib.Indicators.MA.ema_next(state, 6)
  """
  @spec ema_init(list(number), pos_integer) :: {EMAState.t(), list(float | nil)}
  def ema_init(prices, period \\ 50)

  def ema_init(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def ema_init(prices, period) when is_list(prices) do
    if length(prices) < period,
      do: raise(ArgumentError, "ema_init needs at least period (#{period}) prices")

    state = %EMAState{
      period: period,
      multiplier: 2 / (period + 1),
      prev: nil,
      seed: Roll.sum_new(period)
    }

    Roll.replay(prices, state, &ema_next/2)
  end

  @doc """
  Advance streaming EMA state by one price, in O(1).

      iex> {state, _} = TAlib.Indicators.MA.ema_init([1, 2, 3, 4, 5], 2)
      iex> {_state, value} = TAlib.Indicators.MA.ema_next(state, 6)
      iex> value
      5.5
  """
  @spec ema_next(EMAState.t(), number) :: {EMAState.t(), float | nil}
  def ema_next(%EMAState{period: period, seed: seed, prev: nil} = state, price) do
    {seed, sum} = Roll.sum_push(seed, price)

    if is_nil(sum) do
      {%{state | seed: seed}, nil}
    else
      value = sum / period
      {%{state | seed: seed, prev: value}, value}
    end
  end

  def ema_next(%EMAState{multiplier: multiplier, prev: prev} = state, price) do
    value = prev + multiplier * (price - prev)
    {%{state | prev: value}, value}
  end

  @doc """
  Warm up streaming WMA state from `history`: returns `{state, values}`
  (identical to `wma_list/2`) and continues in O(1) via `wma_next/2`.
  History needs at least `period` prices.

      iex> {state, values} = TAlib.Indicators.MA.wma_init([1, 2, 3, 4, 5], 3)
      iex> values
      [nil, nil, 2.3333333333333335, 3.3333333333333335, 4.333333333333333]
      iex> {_state, value} = TAlib.Indicators.MA.wma_next(state, 6)
      iex> Float.round(value, 4)
      5.3333
  """
  @spec wma_init(list(number), pos_integer) :: {WMAState.t(), list(float | nil)}
  def wma_init(prices, period \\ 50)

  def wma_init(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def wma_init(prices, period) when is_list(prices) do
    if length(prices) < period,
      do: raise(ArgumentError, "wma_init needs at least period (#{period}) prices")

    state = %WMAState{
      period: period,
      denominator: period * (period + 1) / 2,
      numerator: 0,
      count: 0,
      sum: Roll.sum_new(period)
    }

    Roll.replay(prices, state, &wma_next/2)
  end

  @doc """
  Advance streaming WMA state by one price, in O(1).

      iex> {state, _} = TAlib.Indicators.MA.wma_init([1, 2, 3, 4, 5], 3)
      iex> {_state, value} = TAlib.Indicators.MA.wma_next(state, 6)
      iex> Float.round(value, 4)
      5.3333
  """
  @spec wma_next(WMAState.t(), number) :: {WMAState.t(), float | nil}
  def wma_next(
        %WMAState{period: period, count: count, numerator: numerator, sum: sum} = state,
        value
      )
      when count < period do
    {sum, _} = Roll.sum_push(sum, value)
    numerator = numerator + value * (count + 1)

    if count + 1 == period do
      {%{state | numerator: numerator, count: count + 1, sum: sum}, numerator / state.denominator}
    else
      {%{state | numerator: numerator, count: count + 1, sum: sum}, nil}
    end
  end

  def wma_next(%WMAState{period: period, numerator: numerator, sum: sum} = state, value) do
    window_sum = sum.sum
    {sum, _} = Roll.sum_push(sum, value)
    numerator = numerator - window_sum + period * value
    {%{state | numerator: numerator, sum: sum}, numerator / state.denominator}
  end

  @doc """
  Warm up streaming RMA (Wilder) state from `history`: returns
  `{state, values}` (identical to `rma_list/2`) and continues in O(1)
  via `rma_next/2`. History needs at least `period` prices.

      iex> {state, values} = TAlib.Indicators.MA.rma_init([1, 2, 3, 4, 5], 3)
      iex> values
      [nil, nil, 2.0, 2.6666666666666665, 3.444444444444444]
      iex> {_state, value} = TAlib.Indicators.MA.rma_next(state, 6)
      iex> Float.round(value, 4)
      4.2963
  """
  @spec rma_init(list(number), pos_integer) :: {RMAState.t(), list(float | nil)}
  def rma_init(prices, period \\ 50)

  def rma_init(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def rma_init(prices, period) when is_list(prices) do
    if length(prices) < period,
      do: raise(ArgumentError, "rma_init needs at least period (#{period}) prices")

    Roll.replay(prices, rma_state_new(period), &rma_next/2)
  end

  @doc false
  # A fresh (unwarmed) RMA state, for indicators that chain one — ATR
  # feeds it True Ranges, for example.
  @spec rma_state_new(pos_integer) :: RMAState.t()
  def rma_state_new(period), do: %RMAState{period: period, prev: nil, seed: Roll.sum_new(period)}

  @doc """
  Advance streaming RMA (Wilder) state by one price, in O(1).

      iex> {state, _} = TAlib.Indicators.MA.rma_init([1, 2, 3, 4, 5], 3)
      iex> {_state, value} = TAlib.Indicators.MA.rma_next(state, 6)
      iex> Float.round(value, 4)
      4.2963
  """
  @spec rma_next(RMAState.t(), number) :: {RMAState.t(), float | nil}
  def rma_next(%RMAState{period: period, seed: seed, prev: nil} = state, price) do
    {seed, sum} = Roll.sum_push(seed, price)

    if is_nil(sum) do
      {%{state | seed: seed}, nil}
    else
      value = sum / period
      {%{state | seed: seed, prev: value}, value}
    end
  end

  def rma_next(%RMAState{period: period, prev: prev} = state, price) do
    value = (prev * (period - 1) + price) / period
    {%{state | prev: value}, value}
  end
end
