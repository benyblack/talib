# Value-audit fixtures and a dump of every TAlib output, for comparison
# against the real TA-Lib C library through its Python bindings. See
# docs/BENCHMARKS.md ("Numerical agreement with TA-Lib").
#
#     mix run bench/audit_dump.exs -- <output-dir> [size]
#
# Writes into <output-dir>: talib_prices.txt (one price per line),
# talib_bars.txt (open,high,low,close,volume per line),
# talib_cdl_bars.txt (open,high,low,close per line) and talib_ours.txt
# (one `name<TAB>comma-separated values` line per function, "nan" for
# nil). The Python side of the audit loads the same files, runs the
# equivalent TA-Lib calls and compares value by value.
#
# The candlestick fixture is pseudo-random (an integer LCG), so the
# pattern thresholds see varied bodies, shadows and gaps rather than
# the smooth bench series.

defmodule TAlib.AuditDump do
  @moduledoc false
  alias TAlib.Indicators.{Aroon, ATR, BBands, CCI, CDL, Donchian, HT, MA, MACD, MAMA, OBV, RSI, StdDev, StochRSI, Stochastic, WilliamsR}

  @lcg_a 1_103_515_245
  @lcg_c 12_345
  @lcg_m 2_147_483_648

  def run(outdir, size, seed) do
    prices =
      Enum.map(0..(size - 1), fn i ->
        100 + 50 * :math.sin(i * 0.03) + rem(i, 13) * 0.7 + i * 0.001
      end)

    bars =
      prices
      |> Enum.with_index()
      |> Enum.map(fn {p, i} ->
        %{
          open: p - 0.4 - rem(i, 3) * 0.1,
          high: p + 1 + rem(i, 5) * 0.3,
          low: p - 1 - rem(i + 2, 4) * 0.25,
          close: p,
          volume: 1000 + 100 * rem(i, 5)
        }
      end)

    cdl_bars = cdl_bars(size, seed)

    write_lines(outdir, "talib_prices.txt", Enum.map(prices, &fmt/1))
    write_lines(outdir, "talib_bars.txt", Enum.map(bars, &bar_line/1))
    write_lines(outdir, "talib_cdl_bars.txt", Enum.map(cdl_bars, &bar_line/1))

    macd_line = MACD.macd_list(prices, 12, 26)
    macd_signal_prefix = macd_line |> Enum.reject(&is_nil/1) |> MA.ema_list(9)
    macd_signal = List.duplicate(nil, 25) ++ macd_signal_prefix
    bbands = BBands.bbands_list(prices, 20, 2)
    ht_sine = HT.ht_sine(prices)
    ht_phasor = HT.ht_phasor(prices)
    mama = MAMA.mama(prices, 0.5, 0.05)
    macdfix = MACD.macd_fix(prices, 12, 26, 9)

    series =
      [
        {"sma", MA.sma_list(prices, 20)},
        {"ema", MA.ema_list(prices, 20)},
        {"wma", MA.wma_list(prices, 20)},
        {"dema", MA.dema_list(prices, 20)},
        {"tema", MA.tema_list(prices, 20)},
        {"t3", MA.t3_list(prices, 5, 0.7)},
        {"kama", MA.kama_list(prices, 20)},
        {"rsi", RSI.rsi_list(prices, 14)},
        {"macd_line", macd_line},
        {"macd_signal", macd_signal},
        {"bbands_upper", Enum.map(bbands, &if(is_map(&1), do: &1.upper, else: nil))},
        {"bbands_middle", Enum.map(bbands, &if(is_map(&1), do: &1.middle, else: nil))},
        {"bbands_lower", Enum.map(bbands, &if(is_map(&1), do: &1.lower, else: nil))},
        {"stoch_fastk", Stochastic.stochastic_k_list(prices, 14)},
        {"williams_r", WilliamsR.williams_r_list(prices, 14)},
        {"midpoint", MA.midpoint_list(prices, 20)},
        {"stochrsi", StochRSI.stoch_rsi_list(prices, 14, 5)},
        {"cci", CCI.cci_list(bars, 20)},
        {"aroon_up", bars |> aroon_series(14) |> Enum.map(&if(is_nil(&1), do: nil, else: elem(&1, 0)))},
        {"aroon_down", bars |> aroon_series(14) |> Enum.map(&if(is_nil(&1), do: nil, else: elem(&1, 1)))},
        {"stddev", StdDev.std_dev_list(prices, 20)},
        {"atr", ATR.atr_list(bars, 14)},
        {"obv", OBV.obv_list(bars)},
        {"ht_trendline", HT.ht_trendline(prices)},
        {"ht_dcperiod", HT.ht_dcperiod(prices)},
        {"ht_dcphase", HT.ht_dcphase(prices)},
        {"ht_sine", ht_sine.sine},
        {"ht_phasor_inphase", ht_phasor.inphase},
        {"ht_phasor_quadrature", ht_phasor.quadrature},
        {"mama", mama.mama},
        {"fama", mama.fama},
        {"macdfix_macd_last", [macdfix.macd]},
        {"macdfix_signal_last", [macdfix.signal]},
        {"macdfix_histogram_last", [macdfix.histogram]}
      ] ++
        streaming_series(prices, bars) ++ cdl_series(cdl_bars)

    content =
      Enum.map_join(series, "\n", fn {name, values} ->
        name <> "\t" <> Enum.map_join(values, ",", &fmt/1)
      end) <> "\n"

    File.write!(Path.join(outdir, "talib_ours.txt"), content)
  end

  # The streaming rows: identical calls computed the `init` + `next`
  # way — warm up on the first four fifths of the fixture, then one
  # O(1) step per remaining bar — proving the streaming path emits
  # exactly what the batch functions (and the C library) do.
  defp streaming_series(prices, bars) do
    closes = Enum.map(bars, & &1.close)

    streamed_macd = fn ->
      {state, values} = MACD.init(Enum.take(prices, div(length(prices), 5) * 4), 12, 26, 9)

      {state, ext} =
        Enum.reduce(Enum.drop(prices, div(length(prices), 5) * 4), {state, []}, fn price, {state, acc} ->
          {state, value} = MACD.next(state, price)
          {state, [value | acc]}
        end)

      %{
        macd: values.macd ++ Enum.map(Enum.reverse(ext), & &1.macd),
        signal: values.signal ++ Enum.map(Enum.reverse(ext), & &1.signal),
        histogram: values.histogram ++ Enum.map(Enum.reverse(ext), & &1.histogram)
      }
    end

    streamed_slow = fn ->
      {state, values} = Stochastic.slow_init(Enum.take(prices, div(length(prices), 5) * 4), 14, 5, 3)

      {state, ext} =
        Enum.reduce(Enum.drop(prices, div(length(prices), 5) * 4), {state, []}, fn price, {state, acc} ->
          {state, value} = Stochastic.slow_next(state, price)
          {state, [value | acc]}
        end)

      %{
        k: values.k ++ Enum.map(Enum.reverse(ext), & &1.k),
        d: values.d ++ Enum.map(Enum.reverse(ext), & &1.d)
      }
    end

    streamed_bbands = fn ->
      band_streamed = streamed(prices, &BBands.init(&1, 20, 2), &BBands.next/2)

      %{
        upper: Enum.map(band_streamed, &if(is_map(&1), do: &1.upper, else: nil)),
        middle: Enum.map(band_streamed, &if(is_map(&1), do: &1.middle, else: nil)),
        lower: Enum.map(band_streamed, &if(is_map(&1), do: &1.lower, else: nil))
      }
    end

    streamed_donchian = fn ->
      streamed(bars, &Donchian.init(&1, 20), &Donchian.next/2)
    end

    macd = streamed_macd.()
    slow = streamed_slow.()
    bbands = streamed_bbands.()
    donchian = streamed_donchian.()

    [
      {"stream_sma", streamed(prices, &MA.sma_init(&1, 20), &MA.sma_next/2)},
      {"stream_ema", streamed(prices, &MA.ema_init(&1, 20), &MA.ema_next/2)},
      {"stream_wma", streamed(prices, &MA.wma_init(&1, 20), &MA.wma_next/2)},
      {"stream_rma", streamed(prices, &MA.rma_init(&1, 20), &MA.rma_next/2)},
      {"stream_stddev", streamed(prices, &StdDev.init(&1, 20), &StdDev.next/2)},
      {"stream_bbands_upper", bbands.upper},
      {"stream_bbands_middle", bbands.middle},
      {"stream_bbands_lower", bbands.lower},
      {"stream_rsi", streamed(prices, &RSI.init(&1, 14), &RSI.next/2)},
      {"stream_atr", streamed(bars, &ATR.init(&1, 14), &ATR.next/2)},
      {"stream_macd", macd.macd},
      {"stream_macd_signal", macd.signal},
      {"stream_macd_histogram", macd.histogram},
      {"stream_stoch_fastk", streamed(prices, &Stochastic.k_init(&1, 14), &Stochastic.k_next/2)},
      {"stream_stoch_slowk", slow.k},
      {"stream_stoch_slowd", slow.d},
      {"stream_williams_r", streamed(prices, &WilliamsR.init(&1, 14), &WilliamsR.next/2)},
      {"stream_aroon_up", streamed(closes, &Aroon.init(&1, 14), &Aroon.next/2) |> Enum.map(&if(is_nil(&1), do: nil, else: elem(&1, 0)))},
      {"stream_aroon_down", streamed(closes, &Aroon.init(&1, 14), &Aroon.next/2) |> Enum.map(&if(is_nil(&1), do: nil, else: elem(&1, 1)))},
      {"stream_donchian_upper", Enum.map(donchian, &if(is_map(&1), do: &1.upper, else: nil))},
      {"stream_donchian_lower", Enum.map(donchian, &if(is_map(&1), do: &1.lower, else: nil))}
    ]
  end

  # Warm up on the first four fifths of the fixture, stream the rest
  # one bar at a time, and return the full streamed series.
  defp streamed(values, init, next) do
    {history, rest} = Enum.split(values, div(length(values), 5) * 4)
    {state, streamed} = init.(history)

    {state, ext} =
      Enum.reduce(rest, {state, []}, fn value, {state, acc} ->
        {state, out} = next.(state, value)
        {state, [out | acc]}
      end)

    streamed ++ Enum.reverse(ext)
  end

  defp cdl_bars(size, seed) do
    0..(size - 1)
    |> Enum.map_reduce(seed, fn _i, x ->
      {x, o_u} = lcg(x)
      {x, c_u} = lcg(x)
      {x, h_u} = lcg(x)
      {x, l_u} = lcg(x)

      open = 100.0 + rem(o_u, 5001) / 10.0
      close = open + (rem(c_u, 4001) - 2000) / 100.0
      body_high = if open >= close, do: open, else: close
      body_low = if open <= close, do: open, else: close

      bar = %{
        open: open,
        close: close,
        high: body_high + rem(h_u, 401) / 100.0,
        low: body_low - rem(l_u, 401) / 100.0,
        volume: 1000
      }

      {bar, x}
    end)
    |> elem(0)
  end

  defp aroon_series(bars, period) do
    bars |> Enum.map(& &1.close) |> Aroon.aroon_list(period)
  end

  defp lcg(x), do: {rem(x * @lcg_a + @lcg_c, @lcg_m), x}

  defp cdl_series(bars) do
    [
      {"CDL2CROWS", &CDL.two_crows/1},
      {"CDL3BLACKCROWS", &CDL.three_black_crows/1},
      {"CDL3INSIDE", &CDL.three_inside/1},
      {"CDL3LINESTRIKE", &CDL.three_line_strike/1},
      {"CDL3OUTSIDE", &CDL.three_outside/1},
      {"CDL3STARSINSOUTH", &CDL.three_stars_in_south/1},
      {"CDL3WHITESOLDIERS", &CDL.three_white_soldiers/1},
      {"CDLABANDONEDBABY", &CDL.abandoned_baby/1},
      {"CDLADVANCEBLOCK", &CDL.advance_block/1},
      {"CDLBELTHOLD", &CDL.belt_hold/1},
      {"CDLBREAKAWAY", &CDL.breakaway/1},
      {"CDLCLOSINGMARUBOZU", &CDL.closing_marubozu/1},
      {"CDLCONCEALBABYSWALL", &CDL.conceal_babys_wall/1},
      {"CDLCOUNTERATTACK", &CDL.counterattack/1},
      {"CDLDARKCLOUDCOVER", &CDL.dark_cloud_cover/1},
      {"CDLDOJI", &CDL.doji/1},
      {"CDLDOJISTAR", &CDL.doji_star/1},
      {"CDLDRAGONFLYDOJI", &CDL.dragonfly_doji/1},
      {"CDLENGULFING", &CDL.engulfing/1},
      {"CDLEVENINGDOJISTAR", &CDL.evening_doji_star/1},
      {"CDLEVENINGSTAR", &CDL.evening_star/1},
      {"CDLGAPSIDESIDEWHITE", &CDL.gap_side_side_white/1},
      {"CDLGRAVESTONEDOJI", &CDL.gravestone_doji/1},
      {"CDLHAMMER", &CDL.hammer/1},
      {"CDLHANGINGMAN", &CDL.hanging_man/1},
      {"CDLHARAMI", &CDL.harami/1},
      {"CDLHARAMICROSS", &CDL.harami_cross/1},
      {"CDLHIGHWAVE", &CDL.high_wave/1},
      {"CDLHIKKAKE", &CDL.hikkake/1},
      {"CDLHIKKAKEMOD", &CDL.hikkake_mod/1},
      {"CDLHOMINGPIGEON", &CDL.homing_pigeon/1},
      {"CDLIDENTICAL3CROWS", &CDL.identical_3_crows/1},
      {"CDLINNECK", &CDL.in_neck/1},
      {"CDLINVERTEDHAMMER", &CDL.inverted_hammer/1},
      {"CDLKICKING", &CDL.kicking/1},
      {"CDLKICKINGBYLENGTH", &CDL.kicking_by_length/1},
      {"CDLLADDERBOTTOM", &CDL.ladder_bottom/1},
      {"CDLLONGLEGGEDDOJI", &CDL.long_legged_doji/1},
      {"CDLLONGLINE", &CDL.long_line/1},
      {"CDLMARUBOZU", &CDL.marubozu/1},
      {"CDLMATCHINGLOW", &CDL.matching_low/1},
      {"CDLMATHOLD", &CDL.mat_hold/1},
      {"CDLMORNINGDOJISTAR", &CDL.morning_doji_star/1},
      {"CDLMORNINGSTAR", &CDL.morning_star/1},
      {"CDLONNECK", &CDL.on_neck/1},
      {"CDLPIERCING", &CDL.piercing/1},
      {"CDLRICKSHAWMAN", &CDL.rickshaw_man/1},
      {"CDLRISEFALL3METHODS", &CDL.rise_fall_3_methods/1},
      {"CDLSEPARATINGLINES", &CDL.separating_lines/1},
      {"CDLSHOOTINGSTAR", &CDL.shooting_star/1},
      {"CDLSHORTLINE", &CDL.short_line/1},
      {"CDLSPINNINGTOP", &CDL.spinning_top/1},
      {"CDLSTALLEDPATTERN", &CDL.stalled_pattern/1},
      {"CDLSTICKSANDWICH", &CDL.stick_sandwich/1},
      {"CDLTAKURI", &CDL.takuri/1},
      {"CDLTASUKIGAP", &CDL.tasuki_gap/1},
      {"CDLTHRUSTING", &CDL.thrusting/1},
      {"CDLTRISTAR", &CDL.tristar/1},
      {"CDLUNIQUE3RIVER", &CDL.unique_3_river/1},
      {"CDLUPSIDEGAP2CROWS", &CDL.upside_gap_2crows/1},
      {"CDLXSIDEGAP3METHODS", &CDL.xside_gap_3methods/1}
    ]
    |> Enum.map(fn {name, fun} -> {name, fun.(bars)} end)
  end

  defp fmt(nil), do: "nan"
  defp fmt(x) when is_integer(x), do: Integer.to_string(x)
  defp fmt(x), do: :erlang.float_to_binary(x * 1.0, [:short])

  defp bar_line(bar) do
    Enum.map_join(
      [bar.open, bar.high, bar.low, bar.close, Map.get(bar, :volume, 0)],
      ",",
      &fmt/1
    )
  end

  defp write_lines(outdir, name, lines) do
    File.write!(Path.join(outdir, name), Enum.join(lines, "\n") <> "\n")
  end
end

outdir = System.argv() |> Enum.at(0) || "."
size = case System.argv() |> Enum.at(1) do
  nil -> 500
  s -> String.to_integer(s)
end

seed = case System.argv() |> Enum.at(2) do
  nil -> 42
  s -> String.to_integer(s)
end

TAlib.AuditDump.run(outdir, size, seed)
IO.puts("audit dump written to #{outdir} (#{size} bars, seed #{seed})")
