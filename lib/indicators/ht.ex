defmodule TAlib.Indicators.HT do
  @moduledoc """
  Hilbert-transform cycle indicators (TA-Lib Cycle Indicators group),
  translated from the TA-Lib C reference implementation of John Ehlers'
  MESA machinery ("Rocket Science for Traders").

  Every function takes prices oldest first and returns series aligned
  with the input: the first 63 entries are `nil` (the fixed warmup of
  the 4-bar WMA pre-smoother and the Hilbert transformer). TA-Lib's
  configurable unstable-period machinery, which shifts where outputs
  begin, is not mirrored. See `TAlib` for the remaining conventions.
  """

  @warmup 37
  @lookback 63
  @a 0.0962
  @b 0.5769
  @rad2deg 45 / :math.atan(1)
  @deg2rad :math.atan(1) / 45
  @deg2rad_by_360 :math.atan(1) * 8

  @doc """
  The Hilbert Transform - Instantaneous Trendline: the raw price
  averaged over the dominant cycle and blended with its own recent
  values.

      iex> TAlib.Indicators.HT.ht_trendline(Enum.to_list(1..100)) |> List.last() |> Float.round(4)
      76.85
  """
  @spec ht_trendline(list(number)) :: list(float | nil)
  def ht_trendline(prices) when is_list(prices) and length(prices) < 64,
    do: List.duplicate(nil, length(prices))

  def ht_trendline(prices) when is_list(prices) do
    {tuple, stream} = core_stream(prices)

    {values, _acc} =
      scan(stream, %{i_trend1: 0, i_trend2: 0, i_trend3: 0}, fn bar, acc ->
        avg = raw_average(tuple, bar.today, bar.dcp_int)

        value =
          (2.0 * acc.i_trend2 + (4.0 * avg + 3.0 * acc.i_trend1) + acc.i_trend3) / 10.0

        {value, %{acc | i_trend3: acc.i_trend2, i_trend2: acc.i_trend1, i_trend1: avg}}
      end)

    align(values)
  end

  @doc """
  The Hilbert Transform - Dominant Cycle Period.

      iex> TAlib.Indicators.HT.ht_dcperiod(Enum.to_list(1..100)) |> List.last() |> Float.round(4)
      45.9889
  """
  @spec ht_dcperiod(list(number)) :: list(float | nil)
  def ht_dcperiod(prices) when is_list(prices) and length(prices) < 64,
    do: List.duplicate(nil, length(prices))

  def ht_dcperiod(prices) when is_list(prices) do
    {_tuple, stream} = core_stream(prices)
    {values, _acc} = scan(stream, :unused, fn bar, acc -> {bar.smooth_period, acc} end)
    align(values)
  end

  @doc """
  The Hilbert Transform - Phasor Components: the in-phase (I1) and
  quadrature (Q1) series, as a map.

      iex> values = TAlib.Indicators.HT.ht_phasor(Enum.to_list(1..100))
      iex> Float.round(List.last(values.quadrature), 4)
      0.8434
  """
  @spec ht_phasor(list(number)) :: %{inphase: list(float | nil), quadrature: list(float | nil)}
  def ht_phasor(prices) when is_list(prices) and length(prices) < 64,
    do: %{
      inphase: List.duplicate(nil, length(prices)),
      quadrature: List.duplicate(nil, length(prices))
    }

  def ht_phasor(prices) when is_list(prices) do
    {_tuple, stream} = core_stream(prices)

    {values, _acc} = scan(stream, :unused, fn bar, acc -> {{bar.i1_prev3, bar.q1}, acc} end)

    values |> align() |> unzip_pair(:inphase, :quadrature)
  end

  @doc """
  The Hilbert Transform - Dominant Cycle Phase, in degrees.

      iex> TAlib.Indicators.HT.ht_dcphase(Enum.to_list(1..100)) |> List.last() |> Float.round(4)
      183.9149
  """
  @spec ht_dcphase(list(number)) :: list(float | nil)
  def ht_dcphase(prices) when is_list(prices) and length(prices) < 64,
    do: List.duplicate(nil, length(prices))

  def ht_dcphase(prices) when is_list(prices) do
    {_tuple, stream} = core_stream(prices)

    {values, _acc} =
      scan(stream, phase_tail(), fn bar, acc ->
        {sp, sp_idx} = push_smooth_price(acc, bar.smoothed)

        dc_phase =
          dominant_cycle_phase(sp, sp_idx, bar.smooth_period, acc.dc_phase, bar.dcp_int)

        {dc_phase,
         %{
           acc
           | smooth_price: sp,
             smooth_price_idx: advance_sp_idx(sp_idx),
             dc_phase: dc_phase
         }}
      end)

    align(values)
  end

  @doc """
  The Hilbert Transform - SineWave: `sine` and `lead_sine` (45 degrees
  ahead), as a map.

      iex> values = TAlib.Indicators.HT.ht_sine(Enum.to_list(1..100))
      iex> Float.round(List.last(values.sine), 4)
      -0.0683
  """
  @spec ht_sine(list(number)) :: %{sine: list(float | nil), lead_sine: list(float | nil)}
  def ht_sine(prices) when is_list(prices) and length(prices) < 64,
    do: %{
      sine: List.duplicate(nil, length(prices)),
      lead_sine: List.duplicate(nil, length(prices))
    }

  def ht_sine(prices) when is_list(prices) do
    {_tuple, stream} = core_stream(prices)

    {values, _acc} =
      scan(stream, phase_tail(), fn bar, acc ->
        {sp, sp_idx} = push_smooth_price(acc, bar.smoothed)

        dc_phase =
          dominant_cycle_phase(sp, sp_idx, bar.smooth_period, acc.dc_phase, bar.dcp_int)

        {{:math.sin(dc_phase * @deg2rad), :math.sin((dc_phase + 45) * @deg2rad)},
         %{
           acc
           | smooth_price: sp,
             smooth_price_idx: advance_sp_idx(sp_idx),
             dc_phase: dc_phase
         }}
      end)

    values |> align() |> unzip_pair(:sine, :lead_sine)
  end

  @doc """
  The Hilbert Transform - Trend vs Cycle Mode: 1 when the price is
  trending, 0 when it is cycling.

      iex> TAlib.Indicators.HT.ht_trendmode(Enum.to_list(1..100)) |> List.last()
      1
  """
  @spec ht_trendmode(list(number)) :: list(0 | 1 | nil)
  def ht_trendmode(prices) when is_list(prices) and length(prices) < 64,
    do: List.duplicate(nil, length(prices))

  def ht_trendmode(prices) when is_list(prices) do
    {tuple, stream} = core_stream(prices)

    {values, _acc} =
      scan(stream, mode_tail(), fn bar, acc ->
        {sp, sp_idx} = push_smooth_price(acc, bar.smoothed)

        dc_phase =
          dominant_cycle_phase(sp, sp_idx, bar.smooth_period, acc.dc_phase, bar.dcp_int)

        avg = raw_average(tuple, bar.today, bar.dcp_int)

        trendline =
          (2.0 * acc.i_trend2 + (4.0 * avg + 3.0 * acc.i_trend1) + acc.i_trend3) / 10.0

        sine = :math.sin(dc_phase * @deg2rad)
        lead_sine = :math.sin((dc_phase + 45) * @deg2rad)

        crossed =
          (sine > lead_sine and acc.prev_sine <= acc.prev_lead_sine) or
            (sine < lead_sine and acc.prev_sine >= acc.prev_lead_sine)

        days_in_trend = if(crossed, do: 0, else: acc.days_in_trend) + 1

        trend =
          cond do
            crossed -> 0
            days_in_trend < 0.5 * bar.smooth_period -> 0
            true -> 1
          end

        delta_phase = dc_phase - acc.prev_dc_phase

        trend =
          if bar.smooth_period != 0.0 and
               delta_phase > 0.67 * 360.0 / bar.smooth_period and
               delta_phase < 1.5 * 360.0 / bar.smooth_period,
             do: 0,
             else: trend

        trend =
          if trendline != 0.0 and abs((elem(sp, sp_idx) - trendline) / trendline) >= 0.015,
            do: 1,
            else: trend

        acc = %{
          acc
          | smooth_price: sp,
            smooth_price_idx: advance_sp_idx(sp_idx),
            dc_phase: dc_phase,
            prev_dc_phase: dc_phase,
            prev_sine: sine,
            prev_lead_sine: lead_sine,
            days_in_trend: days_in_trend,
            i_trend3: acc.i_trend2,
            i_trend2: acc.i_trend1,
            i_trend1: avg
        }

        {trend, acc}
      end)

    align(values)
  end

  # The shared core: `{prices tuple, one bar map per index 37..n-1}`
  # carrying every intermediate the per-indicator tails need.
  @doc false
  def core_stream(prices) do
    tuple = List.to_tuple(prices)

    if tuple_size(tuple) < 64 do
      {tuple, []}
    else
      state = warmup(tuple)
      {tuple, do_stream(tuple, @warmup, tuple_size(tuple) - 1, state, [])}
    end
  end

  defp do_stream(_tuple, today, last, _state, acc) when today > last, do: Enum.reverse(acc)

  defp do_stream(tuple, today, last, state, acc) do
    price = elem(tuple, today)

    adjusted_prev_period = 0.075 * state.period + 0.54

    # 4-bar WMA pre-smoother update.
    period_wma_sub = state.period_wma_sub + price - state.trailing_wma_value
    period_wma_sum = state.period_wma_sum + price * 4.0
    trailing_wma_value = elem(tuple, state.trailing_wma_idx)
    smoothed = period_wma_sum * 0.1
    period_wma_sum = period_wma_sum - period_wma_sub

    state = %{
      state
      | period_wma_sub: period_wma_sub,
        period_wma_sum: period_wma_sum,
        trailing_wma_value: trailing_wma_value,
        trailing_wma_idx: state.trailing_wma_idx + 1
    }

    {detrender, q1, i1_prev3, q2, i2, state} =
      hilbert_bar(state, today, smoothed, adjusted_prev_period)

    # Dominant cycle period from the smoothed complex phasor.
    re = 0.8 * state.re + 0.2 * (i2 * state.prev_i2 + q2 * state.prev_q2)
    im = 0.8 * state.im + 0.2 * (i2 * state.prev_q2 - q2 * state.prev_i2)

    prev_period = state.period

    period =
      if im != 0.0 and re != 0.0,
        do: 360.0 / (:math.atan(im / re) * @rad2deg),
        else: prev_period

    period = min(period, 1.5 * prev_period)
    period = max(period, 0.67 * prev_period)
    period = max(period, 6)
    period = min(period, 50)
    period = period * 0.2 + prev_period * 0.8

    smooth_period = 0.67 * state.smooth_period + 0.33 * period

    state = %{
      state
      | re: re,
        im: im,
        prev_q2: q2,
        prev_i2: i2,
        period: period,
        smooth_period: smooth_period
    }

    bar = %{
      today: today,
      price: price,
      smoothed: smoothed,
      detrender: detrender,
      q1: q1,
      i1_prev3: i1_prev3,
      dcp_int: trunc(smooth_period + 0.5),
      smooth_period: smooth_period
    }

    do_stream(tuple, today + 1, last, state, [bar | acc])
  end

  # The odd/even Hilbert transformers for one bar: detrender, Q1, jI and
  # jQ on the parity's circular buffers, then Q2/I2 and the I1 delays.
  defp hilbert_bar(state, today, smoothed, adjusted_prev_period) do
    parity = if rem(today, 2) == 0, do: :even, else: :odd
    opposite = if parity == :even, do: :odd, else: :even

    {detrender, s} = transformer(state, parity, smoothed, adjusted_prev_period, :detrender)
    {q1, s} = transformer(s, parity, detrender, adjusted_prev_period, :q1)

    i1_prev3 = parity_i1(s, parity, 3)

    {ji, s} = transformer(s, parity, i1_prev3, adjusted_prev_period, :ji)
    {jq, s} = transformer(s, parity, q1, adjusted_prev_period, :jq)

    s = %{s | hilbert_idx: advance_hilbert_idx(s.hilbert_idx)}

    q2 = 0.2 * (q1 + ji) + 0.8 * state.prev_q2
    i2 = 0.2 * (i1_prev3 - jq) + 0.8 * state.prev_i2

    # I1 is the detrender delayed by three bars; each parity keeps its
    # own two-deep delay line and hands the value over on the next bar
    # of the opposite parity.
    s = %{
      s
      | :"i1_#{opposite}_prev3" => Map.fetch!(state, :"i1_#{opposite}_prev2"),
        :"i1_#{opposite}_prev2" => detrender
    }

    {detrender, q1, i1_prev3, q2, i2, s}
  end

  defp parity_i1(state, :even, _n), do: state.i1_even_prev3
  defp parity_i1(state, :odd, _n), do: state.i1_odd_prev3

  # One Hilbert-transformer stage on the odd or even circular buffer,
  # exactly as the C reference computes it.
  defp transformer(state, parity, input, adjusted_prev_period, stage) do
    idx = state.hilbert_idx
    buffer = Map.fetch!(state, :"#{stage}_#{parity}")
    prev = Map.fetch!(state, :"prev_#{stage}_#{parity}")
    prev_input = Map.fetch!(state, :"prev_#{stage}_input_#{parity}")

    temp = @a * input
    value = -elem(buffer, idx)
    buffer = put_elem(buffer, idx, temp)
    value = value + temp
    value = value - prev
    new_prev = @b * prev_input
    value = value + new_prev
    value = value * adjusted_prev_period

    {value,
     %{
       state
       | :"#{stage}_#{parity}" => buffer,
         :"prev_#{stage}_#{parity}" => new_prev,
         :"prev_#{stage}_input_#{parity}" => input
     }}
  end

  defp advance_hilbert_idx(2), do: 0
  defp advance_hilbert_idx(idx), do: idx + 1

  # The warmup: 3 unrolled + 34 rolled WMA steps starting at index 0,
  # leaving `today` at 37.
  defp warmup(tuple) do
    p0 = elem(tuple, 0)
    p1 = elem(tuple, 1)
    p2 = elem(tuple, 2)

    initial_sum = Enum.sum([p0, p1, p2])
    weighted_sum = p0 + p1 * 2 + p2 * 3

    {sub, sum, trailing, idx} =
      Enum.reduce(0..33, {initial_sum, weighted_sum, 0.0, 0}, fn idx,
                                                                 {sub, sum, trailing,
                                                                  trailing_idx} ->
        value = elem(tuple, idx + 3)
        sub = sub + value - trailing
        sum = sum + value * 4.0
        trailing = elem(tuple, trailing_idx)
        sum = sum - sub
        {sub, sum, trailing, idx + 1}
      end)

    blank = {0.0, 0.0, 0.0}

    %{
      period_wma_sub: sub,
      period_wma_sum: sum,
      trailing_wma_value: trailing,
      trailing_wma_idx: idx,
      hilbert_idx: 0,
      detrender_odd: blank,
      detrender_even: blank,
      prev_detrender_odd: 0,
      prev_detrender_even: 0,
      prev_detrender_input_odd: 0,
      prev_detrender_input_even: 0,
      q1_odd: blank,
      q1_even: blank,
      prev_q1_odd: 0,
      prev_q1_even: 0,
      prev_q1_input_odd: 0,
      prev_q1_input_even: 0,
      ji_odd: blank,
      ji_even: blank,
      prev_ji_odd: 0,
      prev_ji_even: 0,
      prev_ji_input_odd: 0,
      prev_ji_input_even: 0,
      jq_odd: blank,
      jq_even: blank,
      prev_jq_odd: 0,
      prev_jq_even: 0,
      prev_jq_input_odd: 0,
      prev_jq_input_even: 0,
      prev_q2: 0,
      prev_i2: 0,
      re: 0,
      im: 0,
      period: 0,
      smooth_period: 0,
      i1_even_prev3: 0,
      i1_even_prev2: 0,
      i1_odd_prev3: 0,
      i1_odd_prev2: 0
    }
  end

  # Average of the raw price over the dominant cycle, ending at `today`
  # (0.0 while the period rounds down to nothing, as in the C code).
  defp raw_average(_tuple, _today, dcp_int) when dcp_int < 1, do: 0.0

  defp raw_average(tuple, today, dcp_int) do
    Enum.reduce(0..(dcp_int - 1), 0.0, fn i, sum -> sum + elem(tuple, today - i) end) /
      dcp_int
  end

  defp push_smooth_price(acc, smoothed) do
    idx = acc.smooth_price_idx
    {put_elem(acc.smooth_price, idx, smoothed), idx}
  end

  defp advance_sp_idx(49), do: 0
  defp advance_sp_idx(idx), do: idx + 1

  defp dominant_cycle_phase(sp, sp_idx, smooth_period, dc_phase, dcp_int) do
    {real_part, imag_part, _idx} =
      if dcp_int < 1 do
        {0.0, 0.0, sp_idx}
      else
        Enum.reduce(0..(dcp_int - 1), {0.0, 0.0, sp_idx}, fn i, {re, im, idx} ->
          angle = i * @deg2rad_by_360 / dcp_int
          value = elem(sp, idx)
          {re + :math.sin(angle) * value, im + :math.cos(angle) * value, step_back(idx)}
        end)
      end

    dc_phase =
      if abs(imag_part) > 0 do
        :math.atan(real_part / imag_part) * @rad2deg
      else
        cond do
          real_part < 0 -> dc_phase - 90
          real_part > 0 -> dc_phase + 90
          true -> dc_phase
        end
      end

    dc_phase = dc_phase + 90 + 360 / smooth_period
    dc_phase = if imag_part < 0, do: dc_phase + 180, else: dc_phase
    if dc_phase > 315, do: dc_phase - 360, else: dc_phase
  end

  defp step_back(0), do: 49
  defp step_back(idx), do: idx - 1

  defp phase_tail do
    %{
      smooth_price: List.to_tuple(List.duplicate(0.0, 50)),
      smooth_price_idx: 0,
      dc_phase: 0
    }
  end

  defp mode_tail do
    Map.merge(phase_tail(), %{
      prev_dc_phase: 0,
      prev_sine: 0,
      prev_lead_sine: 0,
      days_in_trend: 0,
      i_trend1: 0,
      i_trend2: 0,
      i_trend3: 0
    })
  end

  # The tail state machine runs for every stream bar (the C reference
  # warms it up alongside the core); only the output is suppressed
  # before the 63-bar lookback.
  @doc false
  def scan(stream, tail, step) do
    Enum.map_reduce(stream, tail, fn bar, acc ->
      {value, acc} = step.(bar, acc)
      {if(bar.today >= @lookback, do: value, else: nil), acc}
    end)
  end

  @doc false
  def align(values), do: List.duplicate(nil, @warmup) ++ values

  defp unzip_pair(aligned, first_key, second_key) do
    {firsts, seconds} =
      Enum.reduce(aligned, {[], []}, fn
        nil, {f, s} -> {[nil | f], [nil | s]}
        {a, b}, {f, s} -> {[a | f], [b | s]}
      end)

    %{first_key => Enum.reverse(firsts), second_key => Enum.reverse(seconds)}
  end
end
