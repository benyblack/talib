defmodule TAlib.Indicators.Stochastic do
  alias TAlib.Indicators.Roll
  alias TAlib.Indicators.Window
  alias TAlib.Indicators.MA

  @moduledoc """
  Stochastic oscillator [Wikipedia](https://en.wikipedia.org/wiki/Stochastic_oscillator).

  * `%K = (Close - Lowest Low) / (Highest High - Lowest Low) * 100`
  * `%D = SMA(%K, d_period)`

  See `TAlib` for the input conventions: prices are always given in
  chronological order, oldest first, and series are returned aligned with
  the input. `nil` is returned when there is not enough data or the window
  has no range (flat prices), since `%K` is then undefined.

  Note that with a plain price list, close, high and low all come from the
  same series; for proper high/low support an OHLC input shape is needed.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  %K = (Current Close - Lowest Low) / (Highest High - Lowest Low) * 100

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.Stochastic.stochastic_k([1, 2, 5, 1, 4], 5)
      75.0

      iex> TAlib.Indicators.Stochastic.stochastic_k([5, 5, 5], 3)
      nil
  """
  @spec stochastic_k(list(number), pos_integer) :: float | nil
  def stochastic_k(prices, period \\ 14)

  def stochastic_k(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def stochastic_k(prices, period) when is_list(prices) and length(prices) < period, do: nil

  def stochastic_k(prices, period) when is_list(prices) do
    window = Enum.take(prices, -period)
    lowest = Enum.min(window)
    highest = Enum.max(window)

    if highest == lowest do
      nil
    else
      (List.last(window) - lowest) / (highest - lowest) * 100
    end
  end

  @doc """
  Calculate the full %K series.

  Returns a list aligned with `prices`: the first `period - 1` entries are
  `nil`, and every later entry is %K of the window ending at that point.
  Windows with no range (flat prices) produce `nil`, since %K is then
  undefined.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.Stochastic.stochastic_k_list([1, 6, 2, 5, 3], 3)
      [nil, nil, 20.0, 75.0, 33.33333333333333]
  """
  @spec stochastic_k_list(list(number), pos_integer) :: list(float | nil)
  def stochastic_k_list(prices, period \\ 14)

  def stochastic_k_list(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def stochastic_k_list(prices, period) when is_list(prices) and length(prices) < period,
    do: List.duplicate(nil, length(prices))

  def stochastic_k_list(prices, period) when is_list(prices) do
    k_values =
      prices
      |> Window.maxes_mins(period)
      |> Enum.zip(Enum.drop(prices, period - 1))
      |> Enum.map(fn
        {{highest, lowest}, close} when highest != lowest ->
          (close - lowest) / (highest - lowest) * 100

        _ ->
          nil
      end)

    List.duplicate(nil, period - 1) ++ k_values
  end

  @doc """
  %D: the `d_period`-period simple moving average of %K.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: %K lookback window, a positive integer (default 14).
    - d_period: SMA period applied to %K, a positive integer (default 3).

  ## Examples

      iex> TAlib.Indicators.Stochastic.stochastic_d([1, 6, 2, 5, 3, 7, 4], 5, 3)
      60.0
  """
  @spec stochastic_d(list(number), pos_integer, pos_integer) :: float | nil
  def stochastic_d(prices, period \\ 14, d_period \\ 3)

  def stochastic_d(_prices, period, _d_period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def stochastic_d(_prices, _period, d_period) when not is_valid_period(d_period),
    do: TAlib.invalid_period!(d_period)

  def stochastic_d(prices, period, d_period)
      when is_list(prices) and length(prices) < period + d_period - 1,
      do: nil

  def stochastic_d(prices, period, d_period) when is_list(prices) do
    k_values = prices |> stochastic_k_list(period) |> Enum.take(-d_period)

    if Enum.any?(k_values, &is_nil/1) do
      nil
    else
      MA.sma(k_values, d_period)
    end
  end

  @doc """
  The slow stochastic (TA-Lib STOCH): the slowed %K line is the SMA of the
  fast %K over `slowing` bars, and %D is the SMA of the slowed %K.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: %K lookback window, a positive integer (default 14).
    - slowing: SMA period applied to fast %K (default 3).
    - d_period: SMA period applied to the slowed %K (default 3).

  ## Examples

      iex> prices = [1, 6, 2, 5, 3, 7, 4]
      iex> %{k: k, d: d} = TAlib.Indicators.Stochastic.slow(prices, 3, 2, 2)
      iex> {Float.round(k, 4), Float.round(d, 4)}
      {62.5, 64.5833}
  """
  @spec slow(list(number), pos_integer, pos_integer, pos_integer) :: %{
          k: float | nil,
          d: float | nil
        }
  def slow(prices, period \\ 14, slowing \\ 3, d_period \\ 3)

  def slow(_prices, period, _slowing, _d_period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def slow(_prices, _period, slowing, _d_period) when not is_valid_period(slowing),
    do: TAlib.invalid_period!(slowing)

  def slow(_prices, _period, _slowing, d_period) when not is_valid_period(d_period),
    do: TAlib.invalid_period!(d_period)

  def slow(prices, period, slowing, d_period)
      when is_list(prices) and length(prices) < period + slowing + d_period - 2,
      do: %{k: nil, d: nil}

  def slow(prices, period, slowing, d_period) when is_list(prices) do
    k_fast = stochastic_k_list(prices, period) |> Enum.reject(&is_nil/1)

    k_slow = k_fast |> MA.sma_list(slowing) |> Enum.reject(&is_nil/1)
    d_slow = k_slow |> MA.sma_list(d_period) |> Enum.reject(&is_nil/1)

    %{k: List.last(k_slow), d: List.last(d_slow)}
  end

  # ------------------------------------------------------------------
  # Streaming: O(1) per price, rolling extremes via monotonic deques.
  # `init` replays the history through the same arithmetic the batch
  # functions run, so the series continue the batch results bit for
  # bit. A flat window leaves %K (and %R-style values generally)
  # undefined — `k_next/2` returns `nil` for it, and like the batch
  # slow lines the smoothers skip those bars entirely.
  # ------------------------------------------------------------------

  defmodule KState do
    @moduledoc false
    @type t :: %__MODULE__{}
    defstruct [:period, :max, :min]
  end

  defmodule SlowState do
    @moduledoc false
    @type t :: %__MODULE__{}
    defstruct [:k, :slow, :d]
  end

  @doc """
  Warm up streaming fast-%K state from `history`.

  Returns `{state, values}` with `values` the full %K series of
  `history` (identical to `stochastic_k_list/2`), and `state` ready to
  continue it one price at a time in O(1) via `k_next/2`. History
  needs at least `period` prices.

  ## Examples

      iex> {state, values} = TAlib.Indicators.Stochastic.k_init([1, 6, 2, 5, 3], 3)
      iex> values
      [nil, nil, 20.0, 75.0, 33.33333333333333]
      iex> {_state, 100.0} = TAlib.Indicators.Stochastic.k_next(state, 7)
  """
  @spec k_init(list(number), pos_integer) :: {KState.t(), list(float | nil)}
  def k_init(prices, period \\ 14)

  def k_init(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def k_init(prices, period) when is_list(prices) do
    if length(prices) < period,
      do: raise(ArgumentError, "k_init needs at least period (#{period}) prices")

    Roll.replay(prices, k_state_new(period), &k_next/2)
  end

  @doc """
  Advance streaming fast-%K state by one price, in O(1). A flat window
  (no range) yields `nil`, like the batch series.

      iex> {state, _} = TAlib.Indicators.Stochastic.k_init([1, 6, 2, 5, 3], 3)
      iex> {_state, value} = TAlib.Indicators.Stochastic.k_next(state, 7)
      iex> value
      100.0
  """
  @spec k_next(KState.t(), number) :: {KState.t(), float | nil}
  def k_next(%KState{max: max, min: min} = state, price) do
    {max, max_pair} = Roll.max_push(max, price)
    {min, min_pair} = Roll.min_push(min, price)
    state = %{state | max: max, min: min}

    if is_nil(max_pair) do
      {state, nil}
    else
      highest = elem(max_pair, 1)
      lowest = elem(min_pair, 1)

      if highest != lowest do
        {state, (price - lowest) / (highest - lowest) * 100}
      else
        {state, nil}
      end
    end
  end

  @doc """
  Warm up streaming slow-stochastic state (TA-Lib STOCH) from
  `history`: fast %K over `period`, slowed by an SMA of `slowing`, %D
  an SMA of `d_period` over the slowed line.

  Returns `{state, values}` with `values` the two aligned series
  (`%{k: , d: }`), and `state` ready to continue them one price at a
  time in O(1) via `slow_next/2`. History needs at least
  `period + slowing + d_period - 2` prices.

  ## Examples

      iex> {state, values} = TAlib.Indicators.Stochastic.slow_init([1, 6, 2, 5, 3, 7, 4], 3, 2, 2)
      iex> {List.last(values.k), List.last(values.d)}
      {62.49999999999999, 64.58333333333333}
      iex> {_state, %{k: k, d: d}} = TAlib.Indicators.Stochastic.slow_next(state, 5)
      iex> {Float.round(k, 4), Float.round(d, 4)}
      {29.1667, 45.8333}
  """
  @spec slow_init(list(number), pos_integer, pos_integer, pos_integer) ::
          {SlowState.t(), %{k: list(float | nil), d: list(float | nil)}}
  def slow_init(prices, period \\ 14, slowing \\ 3, d_period \\ 3)

  def slow_init(_prices, period, _slowing, _d_period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def slow_init(_prices, _period, slowing, _d_period) when not is_valid_period(slowing),
    do: TAlib.invalid_period!(slowing)

  def slow_init(_prices, _period, _slowing, d_period) when not is_valid_period(d_period),
    do: TAlib.invalid_period!(d_period)

  def slow_init(prices, period, slowing, d_period) when is_list(prices) do
    if length(prices) < period + slowing + d_period - 2,
      do:
        raise(
          ArgumentError,
          "slow_init needs at least period + slowing + d_period - 2 (#{period + slowing + d_period - 2}) prices"
        )

    state = %SlowState{
      k: k_state_new(period),
      slow: Roll.sum_new(slowing),
      d: Roll.sum_new(d_period)
    }

    {state, series} =
      Roll.replay(prices, state, fn state, price ->
        {state, %{k: k, d: d}} = slow_next(state, price)
        {state, {k, d}}
      end)

    {state, %{k: Enum.map(series, &elem(&1, 0)), d: Enum.map(series, &elem(&1, 1))}}
  end

  @doc """
  Advance streaming slow-stochastic state by one price, in O(1):
  `{state, %{k: , d: }}`.

      iex> {state, _} = TAlib.Indicators.Stochastic.slow_init([1, 6, 2, 5, 3, 7, 4], 3, 2, 2)
      iex> {_state, %{k: k, d: d}} = TAlib.Indicators.Stochastic.slow_next(state, 5)
      iex> {Float.round(k, 4), Float.round(d, 4)}
      {29.1667, 45.8333}
  """
  @spec slow_next(SlowState.t(), number) :: {SlowState.t(), %{k: float | nil, d: float | nil}}
  def slow_next(%SlowState{k: kst, slow: slow, d: d} = state, price) do
    {kst, k} = k_next(kst, price)
    state = %{state | k: kst}

    {state, k_slow} =
      if is_nil(k) do
        {state, nil}
      else
        {slow, sum} = Roll.sum_push(slow, k)
        {%{state | slow: slow}, if(is_nil(sum), do: nil, else: sum / slow.period)}
      end

    if is_nil(k_slow) do
      {state, %{k: nil, d: nil}}
    else
      {d, sum} = Roll.sum_push(d, k_slow)
      d_value = if(is_nil(sum), do: nil, else: sum / d.period)
      {%{state | d: d}, %{k: k_slow, d: d_value}}
    end
  end

  defp k_state_new(period),
    do: %KState{period: period, max: Roll.max_new(period), min: Roll.min_new(period)}
end
