defmodule TAlib.Indicators.MACD do
  alias TAlib.Indicators.Roll
  alias TAlib.Indicators.MA

  @moduledoc """
  MACD indicator [Wikipedia](https://en.wikipedia.org/wiki/MACD).

  Calculates the MACD line, the signal line and the histogram. See `TAlib`
  for the input conventions: prices are always given in chronological
  order, oldest first. Every function returns `nil` when there is not
  enough data.

  The MACD line at a point is defined once `max(fast, slow)` prices have
  been seen, but — keeping the behavior of earlier releases — the scalar
  functions require twice that much history (and `macd_all/4` derives its
  guards from the same rule) so that the EMA seed has had time to wash out.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate the latest MACD line value: `EMA(prices, fast) - EMA(prices, slow)`.

  ## Parameters

    - prices: list of prices, oldest first.
    - fast: period of the fast EMA (default 12).
    - slow: period of the slow EMA (default 26).

  At least `max(fast, slow) * 2` prices are required; otherwise `nil` is
  returned.

  ## Examples

      iex> TAlib.Indicators.MACD.macd([1, 4, 3, 5, 2, 6], 3, 2) |> Float.round(4)
      0.4861
  """
  @spec macd(list(number), pos_integer, pos_integer) :: float | nil
  def macd(prices, fast \\ 12, slow \\ 26)

  def macd(_prices, fast, _slow) when not is_valid_period(fast), do: TAlib.invalid_period!(fast)

  def macd(_prices, _fast, slow) when not is_valid_period(slow), do: TAlib.invalid_period!(slow)

  def macd(prices, fast, slow)
      when is_list(prices) and (length(prices) < slow * 2 or length(prices) < fast * 2),
      do: nil

  def macd(prices, fast, slow) when is_list(prices),
    do: prices |> macd_series(fast, slow) |> List.last()

  @doc """
  Calculate the full MACD line series from one fast/slow EMA pass.

  Returns a list aligned with `prices`: entries before index
  `max(fast, slow) - 1` are `nil`, every later entry is
  `EMA(fast) - EMA(slow)` at that point.

  ## Parameters

    - prices: list of prices, oldest first.
    - fast: period of the fast EMA (default 12).
    - slow: period of the slow EMA (default 26).

  ## Examples

      iex> [1, 4, 3, 5, 2, 6] |> TAlib.Indicators.MACD.macd_list(3, 2) |> List.last() |> Float.round(4)
      0.4861
  """
  @spec macd_list(list(number), pos_integer, pos_integer) :: list(float | nil)
  def macd_list(prices, fast \\ 12, slow \\ 26)

  def macd_list(_prices, fast, _slow) when not is_valid_period(fast),
    do: TAlib.invalid_period!(fast)

  def macd_list(_prices, _fast, slow) when not is_valid_period(slow),
    do: TAlib.invalid_period!(slow)

  def macd_list(prices, fast, slow) when is_list(prices), do: macd_series(prices, fast, slow)

  @doc """
  Calculate the latest signal line value: an EMA with the given `period`
  over the MACD series of the last `period * 2` windows.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: EMA period applied to the MACD series (default 9).
    - fast: period of the fast MACD EMA (default 12).
    - slow: period of the slow MACD EMA (default 26).

  At least `max(fast, slow) * 2 + period * 2 - 1` prices are required for
  every MACD value in the signal window to be defined; otherwise `nil` is
  returned.

  ## Examples

      iex> TAlib.Indicators.MACD.signal([5, 1, 6, 4, 7, 3, 8, 2, 9], 2, 3, 2) |> Float.round(4)
      0.3372
  """
  @spec signal(list(number), pos_integer, pos_integer, pos_integer) :: float | nil
  def signal(prices, period \\ 9, fast \\ 12, slow \\ 26)

  def signal(_prices, period, _fast, _slow) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def signal(_prices, _period, fast, _slow) when not is_valid_period(fast),
    do: TAlib.invalid_period!(fast)

  def signal(_prices, _period, _fast, slow) when not is_valid_period(slow),
    do: TAlib.invalid_period!(slow)

  def signal(prices, period, fast, slow) when is_list(prices) do
    if length(prices) < max(fast, slow) * 2 + period * 2 - 1 do
      nil
    else
      prices |> macd_series(fast, slow) |> signal_from_series(fast, slow, period)
    end
  end

  @doc """
  Calculate the latest MACD histogram value: MACD line minus signal line.

  ## Parameters

    - prices: list of prices, oldest first.
    - macd_fast: fast EMA period of the MACD line (default 12).
    - macd_slow: slow EMA period of the MACD line (default 26).
    - signal_period: EMA period of the signal line (default 9).

  ## Examples

      iex> TAlib.Indicators.MACD.histogram([5, 1, 6, 4, 7, 3, 8, 2, 9], 3, 2, 2) |> Float.round(4)
      0.316
  """
  @spec histogram(list(number), pos_integer, pos_integer, pos_integer) :: float | nil
  def histogram(prices, macd_fast \\ 12, macd_slow \\ 26, signal_period \\ 9)

  def histogram(_prices, macd_fast, _macd_slow, _signal_period)
      when not is_valid_period(macd_fast),
      do: TAlib.invalid_period!(macd_fast)

  def histogram(_prices, _macd_fast, macd_slow, _signal_period)
      when not is_valid_period(macd_slow),
      do: TAlib.invalid_period!(macd_slow)

  def histogram(_prices, _macd_fast, _macd_slow, signal_period)
      when not is_valid_period(signal_period),
      do: TAlib.invalid_period!(signal_period)

  def histogram(prices, macd_fast, macd_slow, signal_period) when is_list(prices),
    do: macd_all(prices, macd_fast, macd_slow, signal_period).histogram

  @doc """
  Calculate the MACD line, signal line and histogram of the latest point
  in a single pass over the prices (one fast/slow EMA walk shared by all
  three values).

  ## Parameters

    - prices: list of prices, oldest first.
    - fast: period of the fast MACD EMA (default 12).
    - slow: period of the slow MACD EMA (default 26).
    - signal_period: EMA period of the signal line (default 9).

  Returns a map with `:macd`, `:signal` and `:histogram`. Each value is
  `nil` when its own data requirement is not met, so e.g. the MACD line can
  be defined while the signal line is still `nil`.

  ## Examples

      iex> %{macd: m, signal: s, histogram: h} = TAlib.Indicators.MACD.macd_all([5, 1, 6, 4, 7, 3, 8, 2, 9], 3, 2, 2)
      iex> {Float.round(m, 4), Float.round(s, 4), Float.round(h, 4)}
      {0.6532, 0.3372, 0.316}
  """
  @spec macd_all(list(number), pos_integer, pos_integer, pos_integer) :: %{
          macd: float | nil,
          signal: float | nil,
          histogram: float | nil
        }
  def macd_all(prices, fast \\ 12, slow \\ 26, signal_period \\ 9)

  def macd_all(_prices, fast, _slow, _signal_period) when not is_valid_period(fast),
    do: TAlib.invalid_period!(fast)

  def macd_all(_prices, _fast, slow, _signal_period) when not is_valid_period(slow),
    do: TAlib.invalid_period!(slow)

  def macd_all(_prices, _fast, _slow, signal_period) when not is_valid_period(signal_period),
    do: TAlib.invalid_period!(signal_period)

  def macd_all(prices, fast, slow, signal_period) when is_list(prices) do
    needed = max(fast, slow) * 2
    series = macd_series(prices, fast, slow)

    macd_value =
      if length(prices) >= needed, do: List.last(series), else: nil

    signal_value =
      if length(prices) >= needed + signal_period * 2 - 1,
        do: signal_from_series(series, fast, slow, signal_period),
        else: nil

    histogram_value =
      case {macd_value, signal_value} do
        {m, s} when is_number(m) and is_number(s) -> m - s
        _ -> nil
      end

    %{macd: macd_value, signal: signal_value, histogram: histogram_value}
  end

  # One fast/slow EMA walk with TA-Lib's MACD seeding: the slow EMA is
  # seeded with the average of the first `slow` prices and the fast EMA
  # with the average of the last `fast` of those (both windows end at
  # index slow-1), after which the two advance in lockstep. The line's
  # early values therefore match TA-Lib's MACD bar for bar; from
  # max(fast, slow) * 2 bars on, the seed has washed out and this equals
  # EMA(fast) - EMA(slow).
  defp macd_series(prices, fast, slow) do
    {fast, slow} = if fast <= slow, do: {fast, slow}, else: {slow, fast}
    {prefix, rest} = Enum.split(prices, slow)

    if length(prices) < slow do
      List.duplicate(nil, length(prices))
    else
      slow_seed = Enum.sum(prefix) / slow
      fast_seed = (prefix |> Enum.take(-fast) |> Enum.sum()) / fast
      fast_k = 2 / (fast + 1)
      slow_k = 2 / (slow + 1)

      {values, _} =
        Enum.reduce(rest, {[fast_seed - slow_seed], {fast_seed, slow_seed}}, fn price,
                                                                                {acc, {f, s}} ->
          f = (price - f) * fast_k + f
          s = (price - s) * slow_k + s
          {[f - s | acc], {f, s}}
        end)

      List.duplicate(nil, slow - 1) ++ Enum.reverse(values)
    end
  end

  # EMA over the last period*2 MACD values that satisfy the scalar MACD
  # data requirement (index >= 2 * max(fast, slow) - 1).
  defp signal_from_series(series, fast, slow, period) do
    series
    |> Enum.drop(2 * max(fast, slow) - 1)
    |> Enum.take(-2 * period)
    |> MA.ema(period)
  end

  @doc """
  MACD with configurable moving-average types (TA-Lib MACDEXT): the
  fast line, slow line and signal EMA all use the given `type`
  (default `:ema`, the plain `macd/3` behaviour). Supported types are
  those of `MA.ma/3`.

      iex> %{macd: m, signal: s, histogram: h} = TAlib.Indicators.MACD.macd_ext([1, 4, 3, 5, 2, 6], 3, 2, 2, :sma)
      iex> {Float.round(m, 4), Float.round(s, 4), Float.round(h, 4)}
      {0.3333, 0.0833, 0.25}
  """
  @spec macd_ext(list(number), pos_integer, pos_integer, pos_integer, atom) ::
          %{macd: float | nil, signal: float | nil, histogram: float | nil}
  def macd_ext(prices, fast \\ 12, slow \\ 26, signal_period \\ 9, type \\ :ema)

  def macd_ext(prices, fast, slow, signal_period, type) when is_list(prices) do
    # TA-Lib's MACDEXT computes the EMA variant through the same seeded
    # walk as the plain MACD, so :ema delegates to it; every other type
    # takes the difference of its own series.
    macd_line =
      if type == :ema do
        macd_series(prices, fast, slow)
      else
        fast_series = ma_series_of_type(prices, fast, type)
        slow_series = ma_series_of_type(prices, slow, type)

        fast_series
        |> Enum.zip(slow_series)
        |> Enum.map(fn
          {nil, _} -> nil
          {_, nil} -> nil
          {f, s} -> f - s
        end)
      end

    signal_line = macd_line |> Enum.reject(&is_nil/1) |> ma_series_of_type(signal_period, type)

    macd_value = List.last(macd_line)
    signal_value = List.last(signal_line)

    histogram_value =
      case {macd_value, signal_value} do
        {m, s} when is_number(m) and is_number(s) -> m - s
        _ -> nil
      end

    %{macd: macd_value, signal: signal_value, histogram: histogram_value}
  end

  defp ma_series_of_type(prices, period, type) do
    case type do
      :sma -> MA.sma_list(prices, period)
      :ema -> MA.ema_list(prices, period)
      :wma -> MA.wma_list(prices, period)
      :dema -> MA.dema_list(prices, period)
      :tema -> MA.tema_list(prices, period)
      :trima -> MA.trima_list(prices, period)
      :kama -> MA.kama_list(prices, period)
      :t3 -> MA.t3_list(prices, period)
      type -> raise(ArgumentError, "unknown MA type #{inspect(type)}")
    end
  end

  @doc """
  MACD with the TA-Lib MACDFIX signal convention: the signal line is
  the EMA over the whole MACD series starting at its first defined
  value (rather than a trailing window).

      iex> TAlib.Indicators.MACD.macd_fix([1, 4, 3, 5, 2, 6], 3, 2, 2) |> Map.get(:macd) |> Float.round(4)
      0.4861
  """
  @spec macd_fix(list(number), pos_integer, pos_integer, pos_integer) ::
          %{macd: float | nil, signal: float | nil, histogram: float | nil}
  def macd_fix(prices, fast \\ 12, slow \\ 26, signal_period \\ 9)

  def macd_fix(prices, fast, slow, signal_period) when is_list(prices) do
    macd_line = prices |> macd_series(fast, slow) |> Enum.reject(&is_nil/1)
    signal_line = macd_line |> MA.ema_list(signal_period) |> Enum.reject(&is_nil/1)

    macd_value = List.last(macd_line)
    signal_value = List.last(signal_line)

    histogram_value =
      case {macd_value, signal_value} do
        {m, s} when is_number(m) and is_number(s) -> m - s
        _ -> nil
      end

    %{macd: macd_value, signal: signal_value, histogram: histogram_value}
  end

  # ------------------------------------------------------------------
  # Streaming: O(1) per price. `init` replays the history through the
  # same seeded fast/slow walk as `macd_series/3` and the same whole-
  # series signal EMA as `macd_fix/4` (the MACDFIX convention — the
  # natural one to continue a feed from), so the three series continue
  # the batch results bit for bit. As everywhere, `fast` and `slow`
  # are normalized so the slow line is the longer one; history needs
  # at least `slow + signal_period - 1` prices.
  # ------------------------------------------------------------------

  defmodule State do
    @moduledoc false
    @type t :: %__MODULE__{}
    defstruct [
      :fast,
      :slow,
      :signal_period,
      :fast_k,
      :slow_k,
      :signal_k,
      :prefix,
      :prefix_count,
      :f,
      :s,
      :signal_prefix,
      :signal_count,
      :sig
    ]
  end

  @doc """
  Warm up streaming MACD state from `history`.

  Returns `{state, values}` where `values` carries the three aligned
  series — `%{macd: , signal: , histogram: }` — of `history`: the MACD
  line equals `macd_list/3`, and the signal line is the whole-series
  EMA of it (the `macd_fix/4` convention). `state` continues all three
  one price at a time in O(1) via `next/2`.

  ## Examples

      iex> {state, values} = TAlib.Indicators.MACD.init([5, 1, 6, 4, 7, 3, 8, 2, 9], 3, 2, 2)
      iex> List.last(values.macd) |> Float.round(4)
      0.6532
      iex> {_state, %{macd: m, signal: s, histogram: h}} = TAlib.Indicators.MACD.next(state, 7)
      iex> {Float.round(m, 4), Float.round(s, 4), Float.round(h, 4)}
      {0.2959, 0.3165, -0.0206}
  """
  @spec init(list(number), pos_integer, pos_integer, pos_integer) ::
          {State.t(),
           %{macd: list(float | nil), signal: list(float | nil), histogram: list(float | nil)}}
  def init(prices, fast \\ 12, slow \\ 26, signal_period \\ 9)

  def init(_prices, fast, _slow, _signal_period) when not is_valid_period(fast),
    do: TAlib.invalid_period!(fast)

  def init(_prices, _fast, slow, _signal_period) when not is_valid_period(slow),
    do: TAlib.invalid_period!(slow)

  def init(_prices, _fast, _slow, signal_period) when not is_valid_period(signal_period),
    do: TAlib.invalid_period!(signal_period)

  def init(prices, fast, slow, signal_period) when is_list(prices) do
    {fast, slow} = if fast <= slow, do: {fast, slow}, else: {slow, fast}

    if length(prices) < slow + signal_period - 1,
      do:
        raise(
          ArgumentError,
          "init needs at least slow + signal - 1 (#{slow + signal_period - 1}) prices"
        )

    state = %State{
      fast: fast,
      slow: slow,
      signal_period: signal_period,
      fast_k: 2 / (fast + 1),
      slow_k: 2 / (slow + 1),
      signal_k: 2 / (signal_period + 1),
      prefix: :queue.new(),
      prefix_count: 0,
      signal_prefix: :queue.new(),
      signal_count: 0
    }

    {state, series} =
      Roll.replay(prices, state, fn state, price ->
        {state, %{macd: m, signal: s, histogram: h}} = next(state, price)
        {state, {m, s, h}}
      end)

    unzip = fn tuples, idx -> Enum.map(tuples, &elem(&1, idx)) end

    {state,
     %{
       macd: unzip.(series, 0),
       signal: unzip.(series, 1),
       histogram: unzip.(series, 2)
     }}
  end

  @doc """
  Advance streaming MACD state by one price, in O(1):
  `{state, %{macd: , signal: , histogram: }}`.

      iex> {state, _} = TAlib.Indicators.MACD.init([5, 1, 6, 4, 7, 3, 8, 2, 9], 3, 2, 2)
      iex> {_state, %{macd: m, signal: s, histogram: h}} = TAlib.Indicators.MACD.next(state, 7)
      iex> {Float.round(m, 4), Float.round(s, 4), Float.round(h, 4)}
      {0.2959, 0.3165, -0.0206}
  """
  @spec next(State.t(), number) ::
          {State.t(), %{macd: float | nil, signal: float | nil, histogram: float | nil}}
  def next(%State{prefix_count: count, slow: slow} = state, price) when count < slow - 1 do
    {%{state | prefix: :queue.in(price, state.prefix), prefix_count: count + 1},
     %{macd: nil, signal: nil, histogram: nil}}
  end

  def next(%State{prefix_count: count, slow: slow} = state, price) when count == slow - 1 do
    prefix = state.prefix |> then(&:queue.in(price, &1)) |> :queue.to_list()
    slow_seed = Enum.sum(prefix) / slow
    fast_seed = (prefix |> Enum.take(-state.fast) |> Enum.sum()) / state.fast

    state = %{state | prefix_count: count + 1, f: fast_seed, s: slow_seed}
    signal_step(state, fast_seed - slow_seed)
  end

  def next(%State{fast_k: fast_k, slow_k: slow_k, f: f, s: s} = state, price) do
    f = (price - f) * fast_k + f
    s = (price - s) * slow_k + s
    signal_step(%{state | f: f, s: s}, f - s)
  end

  defp signal_step(%State{signal_count: count, signal_period: period} = state, macd)
       when count < period - 1 do
    {%{state | signal_prefix: :queue.in(macd, state.signal_prefix), signal_count: count + 1},
     %{macd: macd, signal: nil, histogram: nil}}
  end

  defp signal_step(%State{signal_count: count, signal_period: period} = state, macd)
       when count == period - 1 do
    macds = state.signal_prefix |> then(&:queue.in(macd, &1)) |> :queue.to_list()
    signal = Enum.sum(macds) / period

    {%{state | signal_count: count + 1, sig: signal},
     %{macd: macd, signal: signal, histogram: macd - signal}}
  end

  defp signal_step(%State{signal_k: signal_k, sig: sig} = state, macd) do
    signal = sig + signal_k * (macd - sig)
    {%{state | sig: signal}, %{macd: macd, signal: signal, histogram: macd - signal}}
  end
end
