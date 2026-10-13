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
  # The DCPERIOD/PHASOR (and MAMA) family warms the WMA with 12 bars
  # and emits from bar 32, as in TA-Lib; the rest use 37/63.
  @warmup_short 12
  @lookback_short 32
  @a 0.0962
  @b 0.5769
  @rad2deg 45 / :math.atan(1)
  @deg2rad :math.atan(1) / 45
  @deg2rad_by_360 :math.atan(1) * 8

  # ------------------------------------------------------------------
  # Container layout: the transformer state and each emitted bar are
  # fixed-layout tuples (below) — the arithmetic they carry is exactly
  # the C reference's, so the outputs stay bit-for-bit identical; the
  # tuples just keep the per-bar cost to O(1) element reads/writes
  # instead of map updates.
  # ------------------------------------------------------------------

  # State tuple slots (elem indices).
  @s_sub 0
  @s_sum 1
  @s_trailing 2
  @s_trailing_idx 3
  @s_hilbert_idx 4
  @s_det_odd 5
  @s_det_odd_prev 6
  @s_det_odd_in 7
  @s_det_even 8
  @s_det_even_prev 9
  @s_det_even_in 10
  @s_q1_odd 11
  @s_q1_odd_prev 12
  @s_q1_odd_in 13
  @s_q1_even 14
  @s_q1_even_prev 15
  @s_q1_even_in 16
  @s_ji_odd 17
  @s_ji_odd_prev 18
  @s_ji_odd_in 19
  @s_ji_even 20
  @s_ji_even_prev 21
  @s_ji_even_in 22
  @s_jq_odd 23
  @s_jq_odd_prev 24
  @s_jq_odd_in 25
  @s_jq_even 26
  @s_jq_even_prev 27
  @s_jq_even_in 28
  @s_prev_q2 29
  @s_prev_i2 30
  @s_re 31
  @s_im 32
  @s_period 33
  @s_smooth_period 34
  @s_i1_even_prev3 35
  @s_i1_even_prev2 36
  @s_i1_odd_prev3 37
  @s_i1_odd_prev2 38

  # Bar tuple slots: what the per-indicator tails read.
  @b_today 0
  @b_price 1
  @b_smoothed 2
  @b_q1 3
  @b_i1_prev3 4
  @b_dcp_int 5
  @b_smooth_period 6

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
      scan(stream, {0, 0, 0}, fn bar, {t1, t2, t3} ->
        avg = raw_average(tuple, elem(bar, @b_today), elem(bar, @b_dcp_int))

        value = (2.0 * t2 + (4.0 * avg + 3.0 * t1) + t3) / 10.0

        {value, {avg, t1, t2}}
      end)

    align(values)
  end

  @doc """
  The Hilbert Transform - Dominant Cycle Period.

      iex> TAlib.Indicators.HT.ht_dcperiod(Enum.to_list(1..100)) |> List.last() |> Float.round(4)
      42.5223
  """
  @spec ht_dcperiod(list(number)) :: list(float | nil)
  def ht_dcperiod(prices) when is_list(prices) and length(prices) < 64,
    do: List.duplicate(nil, length(prices))

  def ht_dcperiod(prices) when is_list(prices) do
    {_tuple, stream} = core_stream(prices, @warmup_short)

    {values, _acc} =
      scan(stream, :unused, @lookback_short, fn bar, acc ->
        {elem(bar, @b_smooth_period), acc}
      end)

    align(values, @warmup_short)
  end

  @doc """
  The Hilbert Transform - Phasor Components: the in-phase (I1) and
  quadrature (Q1) series, as a map.

      iex> values = TAlib.Indicators.HT.ht_phasor(Enum.to_list(1..100))
      iex> Float.round(List.last(values.quadrature), 4)
      -1.9195
  """
  @spec ht_phasor(list(number)) :: %{inphase: list(float | nil), quadrature: list(float | nil)}
  def ht_phasor(prices) when is_list(prices) and length(prices) < 64,
    do: %{
      inphase: List.duplicate(nil, length(prices)),
      quadrature: List.duplicate(nil, length(prices))
    }

  def ht_phasor(prices) when is_list(prices) do
    {_tuple, stream} = core_stream(prices, @warmup_short)

    {values, _acc} =
      scan(stream, :unused, @lookback_short, fn bar, acc ->
        value =
          if elem(bar, @b_today) >= @lookback_short,
            do: {elem(bar, @b_i1_prev3), elem(bar, @b_q1)},
            else: nil

        {value, acc}
      end)

    values |> align(@warmup_short) |> unzip_pair(:inphase, :quadrature)
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
      scan(stream, phase_tail(), fn bar, {sp, sp_idx, dc_phase} ->
        sp = put_elem(sp, sp_idx, elem(bar, @b_smoothed))

        dc_phase =
          dominant_cycle_phase(
            sp,
            sp_idx,
            elem(bar, @b_smooth_period),
            dc_phase,
            elem(bar, @b_dcp_int)
          )

        {dc_phase, {sp, advance_sp_idx(sp_idx), dc_phase}}
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
      scan(stream, phase_tail(), fn bar, {sp, sp_idx, dc_phase} ->
        sp = put_elem(sp, sp_idx, elem(bar, @b_smoothed))

        dc_phase =
          dominant_cycle_phase(
            sp,
            sp_idx,
            elem(bar, @b_smooth_period),
            dc_phase,
            elem(bar, @b_dcp_int)
          )

        {{:math.sin(dc_phase * @deg2rad), :math.sin((dc_phase + 45) * @deg2rad)},
         {sp, advance_sp_idx(sp_idx), dc_phase}}
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
      scan(stream, mode_tail(), fn bar,
                                   {sp, sp_idx, dc_phase, prev_dc_phase, prev_sine,
                                    prev_lead_sine, days_in_trend, t1, t2, t3} ->
        sp = put_elem(sp, sp_idx, elem(bar, @b_smoothed))
        smooth_period = elem(bar, @b_smooth_period)

        dc_phase =
          dominant_cycle_phase(sp, sp_idx, smooth_period, dc_phase, elem(bar, @b_dcp_int))

        avg = raw_average(tuple, elem(bar, @b_today), elem(bar, @b_dcp_int))

        trendline = (2.0 * t2 + (4.0 * avg + 3.0 * t1) + t3) / 10.0

        sine = :math.sin(dc_phase * @deg2rad)
        lead_sine = :math.sin((dc_phase + 45) * @deg2rad)

        crossed =
          (sine > lead_sine and prev_sine <= prev_lead_sine) or
            (sine < lead_sine and prev_sine >= prev_lead_sine)

        days_in_trend = if(crossed, do: 0, else: days_in_trend) + 1

        trend =
          cond do
            crossed -> 0
            days_in_trend < 0.5 * smooth_period -> 0
            true -> 1
          end

        delta_phase = dc_phase - prev_dc_phase

        trend =
          if smooth_period != 0.0 and
               delta_phase > 0.67 * 360.0 / smooth_period and
               delta_phase < 1.5 * 360.0 / smooth_period,
             do: 0,
             else: trend

        trend =
          if trendline != 0.0 and abs((elem(sp, sp_idx) - trendline) / trendline) >= 0.015,
            do: 1,
            else: trend

        {trend,
         {sp, advance_sp_idx(sp_idx), dc_phase, dc_phase, sine, lead_sine, days_in_trend, avg, t1,
          t2}}
      end)

    align(values)
  end

  # The shared core: `{prices tuple, one bar tuple per index
  # (warmup+1)..n-1}` carrying every intermediate the per-indicator
  # tails need. The warmup length selects the TA-Lib family: 37 bars
  # for the 63-lookback indicators, 12 for the 32-lookback ones.
  @doc false
  def core_stream(prices, warmup) do
    tuple = List.to_tuple(prices)

    if tuple_size(tuple) < 64 do
      {tuple, []}
    else
      state = warmup(tuple, warmup - 3)
      {tuple, do_stream(tuple, warmup, tuple_size(tuple) - 1, state, [])}
    end
  end

  def core_stream(prices), do: core_stream(prices, @warmup)

  # Bar accessors for the other MESA modules (MAMA): the layout is
  # module-private, so the few cross-module reads go through here.
  @doc false
  def bar_price(bar), do: elem(bar, @b_price)

  @doc false
  def bar_q1_i1(bar), do: {elem(bar, @b_q1), elem(bar, @b_i1_prev3)}

  defp do_stream(_tuple, today, last, _state, acc) when today > last, do: Enum.reverse(acc)

  defp do_stream(tuple, today, last, state, acc) do
    price = elem(tuple, today)

    adjusted_prev_period = 0.075 * elem(state, @s_period) + 0.54

    # 4-bar WMA pre-smoother update.
    sub = elem(state, @s_sub) + price - elem(state, @s_trailing)
    sum0 = elem(state, @s_sum) + price * 4.0
    trailing = elem(tuple, elem(state, @s_trailing_idx))
    smoothed = sum0 * 0.1
    sum = sum0 - sub

    state =
      state
      |> put_elem(@s_sub, sub)
      |> put_elem(@s_sum, sum)
      |> put_elem(@s_trailing, trailing)
      |> put_elem(@s_trailing_idx, elem(state, @s_trailing_idx) + 1)

    {_detrender, q1, i1_prev3, q2, i2, state} =
      hilbert_bar(state, today, smoothed, adjusted_prev_period)

    prev_q2 = elem(state, @s_prev_q2)
    prev_i2 = elem(state, @s_prev_i2)

    # Dominant cycle period from the smoothed complex phasor.
    re = 0.8 * elem(state, @s_re) + 0.2 * (i2 * prev_i2 + q2 * prev_q2)
    im = 0.8 * elem(state, @s_im) + 0.2 * (i2 * prev_q2 - q2 * prev_i2)

    prev_period = elem(state, @s_period)

    period =
      if im != 0.0 and re != 0.0,
        do: 360.0 / (:math.atan(im / re) * @rad2deg),
        else: prev_period

    period = min(period, 1.5 * prev_period)
    period = max(period, 0.67 * prev_period)
    period = max(period, 6)
    period = min(period, 50)
    period = period * 0.2 + prev_period * 0.8

    smooth_period = 0.67 * elem(state, @s_smooth_period) + 0.33 * period

    state =
      state
      |> put_elem(@s_re, re)
      |> put_elem(@s_im, im)
      |> put_elem(@s_prev_q2, q2)
      |> put_elem(@s_prev_i2, i2)
      |> put_elem(@s_period, period)
      |> put_elem(@s_smooth_period, smooth_period)

    bar =
      {today, price, smoothed, q1, i1_prev3, trunc(smooth_period + 0.5), smooth_period}

    do_stream(tuple, today + 1, last, state, [bar | acc])
  end

  # The odd/even Hilbert transformers for one bar: detrender, Q1, jI and
  # jQ on the parity's circular buffers, then Q2/I2 and the I1 delays.
  defp hilbert_bar(state, today, smoothed, adjusted_prev_period) do
    parity = if rem(today, 2) == 0, do: :even, else: :odd
    opposite = if parity == :even, do: :odd, else: :even

    {detrender, state} =
      transformer(state, smoothed, adjusted_prev_period, stage_slots(:detrender, parity))

    {q1, state} = transformer(state, detrender, adjusted_prev_period, stage_slots(:q1, parity))

    i1_prev3 = i1_prev3(state, parity)

    {ji, state} = transformer(state, i1_prev3, adjusted_prev_period, stage_slots(:ji, parity))
    {jq, state} = transformer(state, q1, adjusted_prev_period, stage_slots(:jq, parity))

    state =
      put_elem(
        state,
        @s_hilbert_idx,
        advance_hilbert_idx(elem(state, @s_hilbert_idx))
      )

    prev_q2 = elem(state, @s_prev_q2)
    prev_i2 = elem(state, @s_prev_i2)

    q2 = 0.2 * (q1 + ji) + 0.8 * prev_q2
    i2 = 0.2 * (i1_prev3 - jq) + 0.8 * prev_i2

    # I1 is the detrender delayed by three bars; each parity keeps its
    # own two-deep delay line and hands the value over on the next bar
    # of the opposite parity.
    state =
      state
      |> put_elem(i1_slot(opposite, 3), i1_prev3(state, opposite, 2))
      |> put_elem(i1_slot(opposite, 2), detrender)

    {detrender, q1, i1_prev3, q2, i2, state}
  end

  defp i1_prev3(state, :even), do: elem(state, @s_i1_even_prev3)
  defp i1_prev3(state, :odd), do: elem(state, @s_i1_odd_prev3)

  defp i1_prev3(state, :even, 2), do: elem(state, @s_i1_even_prev2)
  defp i1_prev3(state, :even, 3), do: elem(state, @s_i1_even_prev3)

  defp i1_prev3(state, :odd, 2), do: elem(state, @s_i1_odd_prev2)
  defp i1_prev3(state, :odd, 3), do: elem(state, @s_i1_odd_prev3)

  defp i1_slot(:even, 3), do: @s_i1_even_prev3
  defp i1_slot(:even, 2), do: @s_i1_even_prev2
  defp i1_slot(:odd, 3), do: @s_i1_odd_prev3
  defp i1_slot(:odd, 2), do: @s_i1_odd_prev2

  # One Hilbert-transformer stage on the odd or even circular buffer,
  # exactly as the C reference computes it.
  defp stage_slots(:detrender, :odd), do: {@s_det_odd, @s_det_odd_prev, @s_det_odd_in}
  defp stage_slots(:detrender, :even), do: {@s_det_even, @s_det_even_prev, @s_det_even_in}
  defp stage_slots(:q1, :odd), do: {@s_q1_odd, @s_q1_odd_prev, @s_q1_odd_in}
  defp stage_slots(:q1, :even), do: {@s_q1_even, @s_q1_even_prev, @s_q1_even_in}
  defp stage_slots(:ji, :odd), do: {@s_ji_odd, @s_ji_odd_prev, @s_ji_odd_in}
  defp stage_slots(:ji, :even), do: {@s_ji_even, @s_ji_even_prev, @s_ji_even_in}
  defp stage_slots(:jq, :odd), do: {@s_jq_odd, @s_jq_odd_prev, @s_jq_odd_in}
  defp stage_slots(:jq, :even), do: {@s_jq_even, @s_jq_even_prev, @s_jq_even_in}

  defp transformer(s, input, adjusted_prev_period, {buf_i, prev_i, in_i}) do
    idx = elem(s, @s_hilbert_idx)
    buffer = elem(s, buf_i)
    prev = elem(s, prev_i)
    prev_input = elem(s, in_i)

    temp = @a * input
    value = -elem(buffer, idx)
    buffer = put_elem(buffer, idx, temp)
    value = value + temp
    value = value - prev
    new_prev = @b * prev_input
    value = value + new_prev
    value = value * adjusted_prev_period

    {value,
     s
     |> put_elem(buf_i, buffer)
     |> put_elem(prev_i, new_prev)
     |> put_elem(in_i, input)}
  end

  defp advance_hilbert_idx(2), do: 0
  defp advance_hilbert_idx(idx), do: idx + 1

  # The warmup: 3 unrolled plus `extra` rolled WMA steps starting at
  # index 0 (extra = 34 leaves `today` at 37; 9 leaves it at 12).
  defp warmup(tuple, extra) do
    p0 = elem(tuple, 0)
    p1 = elem(tuple, 1)
    p2 = elem(tuple, 2)

    initial_sum = Enum.sum([p0, p1, p2])
    weighted_sum = p0 + p1 * 2 + p2 * 3

    {sub, sum, trailing, idx} =
      Enum.reduce(0..(extra - 1), {initial_sum, weighted_sum, 0.0, 0}, fn idx,
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

    {
      # WMA pre-smoother
      sub,
      sum,
      trailing,
      idx,
      # transformer ring index
      0,
      # detrender: odd buffer/prev/input, then even
      blank,
      0,
      0,
      blank,
      0,
      0,
      # q1
      blank,
      0,
      0,
      blank,
      0,
      0,
      # ji
      blank,
      0,
      0,
      blank,
      0,
      0,
      # jq
      blank,
      0,
      0,
      blank,
      0,
      0,
      # complex phasor smoothing and the period
      0,
      0,
      0,
      0,
      0,
      0,
      # I1 delay lines, even then odd
      0,
      0,
      0,
      0
    }
  end

  # Average of the raw price over the dominant cycle, ending at `today`
  # (0.0 while the period rounds down to nothing, as in the C code).
  defp raw_average(_tuple, _today, dcp_int) when dcp_int < 1, do: 0.0

  defp raw_average(tuple, today, dcp_int) do
    Enum.reduce(0..(dcp_int - 1), 0.0, fn i, sum -> sum + elem(tuple, today - i) end) /
      dcp_int
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

  # Phase-family tail state: {smooth price ring (50), ring index,
  # dominant cycle phase}.
  defp phase_tail do
    {List.to_tuple(List.duplicate(0.0, 50)), 0, 0}
  end

  # Trend-mode tail: the phase tail plus {prev dc phase, prev sine,
  # prev lead sine, days in trend, i_trend1..3}.
  defp mode_tail do
    {sp, idx, phase} = phase_tail()
    {sp, idx, phase, 0, 0, 0, 0, 0, 0, 0}
  end

  # The tail state machine runs for every stream bar (the C reference
  # warms it up alongside the core); only the output is suppressed
  # before the 63-bar lookback.
  @doc false
  def scan(stream, tail, lookback, step) do
    Enum.map_reduce(stream, tail, fn bar, acc ->
      {value, acc} = step.(bar, acc)
      {if(elem(bar, @b_today) >= lookback, do: value, else: nil), acc}
    end)
  end

  def scan(stream, tail, step), do: scan(stream, tail, @lookback, step)

  @doc false
  def align(values, warmup), do: List.duplicate(nil, warmup) ++ values

  def align(values), do: align(values, @warmup)

  defp unzip_pair(aligned, first_key, second_key) do
    {firsts, seconds} =
      Enum.reduce(aligned, {[], []}, fn
        nil, {f, s} -> {[nil | f], [nil | s]}
        {a, b}, {f, s} -> {[a | f], [b | s]}
      end)

    %{first_key => Enum.reverse(firsts), second_key => Enum.reverse(seconds)}
  end
end
