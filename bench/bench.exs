# Benchmark harness: wall-clock timings for representative TAlib
# functions on deterministic data, printed as JSON lines.
#
#     mix run bench/bench.exs [size]
#
# Deliberately dependency-free so it runs anywhere the project compiles.

size = case System.argv() do
  [n] -> String.to_integer(n)
  _ -> 100_000
end

# Deterministic price series (same formula as bench/bench.py).
prices =
  Enum.map(0..(size - 1), fn i ->
    100 + 50 * :math.sin(i * 0.03) + rem(i, 13) * 0.7 + i * 0.001
  end)

bars =
  Enum.with_index(prices)
  |> Enum.map(fn {p, i} ->
    %{
      open: p - 0.4 - rem(i, 3) * 0.1,
      high: p + 1 + rem(i, 5) * 0.3,
      low: p - 1 - rem(i + 2, 4) * 0.25,
      close: p,
      volume: 1000 + 100 * rem(i, 5)
    }
  end)

alias TAlib.Indicators.{MA, RSI, MACD, BBands, ATR, OBV, StdDev, CDL, HT, MAMA}

jobs = [
  {"MA.sma_list/2 (20)", fn -> MA.sma_list(prices, 20) end},
  {"MA.ema_list/2 (20)", fn -> MA.ema_list(prices, 20) end},
  {"MA.wma_list/2 (20)", fn -> MA.wma_list(prices, 20) end},
  {"MA.dema_list/2 (20)", fn -> MA.dema_list(prices, 20) end},
  {"MA.kama_list/2 (20)", fn -> MA.kama_list(prices, 20) end},
  {"RSI.rsi_list/2 (14)", fn -> RSI.rsi_list(prices, 14) end},
  {"MACD.macd_fix/4 (12/26/9)", fn -> MACD.macd_fix(prices, 12, 26, 9) end},
  {"BBands.bbands_list/3 (20,2)", fn -> BBands.bbands_list(prices, 20, 2) end},
  {"StdDev.std_dev_list/2 (20)", fn -> StdDev.std_dev_list(prices, 20) end},
  {"ATR.atr_list/2 (14) [bars]", fn -> ATR.atr_list(bars, 14) end},
  {"OBV.obv_list/1 [bars]", fn -> OBV.obv_list(bars) end},
  {"CDL.doji/2", fn -> CDL.doji(bars) end},
  {"CDL.engulfing/2", fn -> CDL.engulfing(bars) end},
  {"CDL.three_white_soldiers/2", fn -> CDL.three_white_soldiers(bars) end},
  {"HT.ht_trendline/1", fn -> HT.ht_trendline(prices) end},
  {"HT.ht_dcphase/1", fn -> HT.ht_dcphase(prices) end},
  {"MAMA.mama/3 (0.5,0.05)", fn -> MAMA.mama(prices, 0.5, 0.05) end}
]

# Warmup once, then report the median of N runs (a min is fragile
# against occasional zero timer readings).
warmups = 1
runs = if size >= 100_000, do: 5, else: 20

Enum.each(jobs, fn {name, fun} ->
  Enum.each(1..warmups, fn _ -> fun.() end)

  times =
    Enum.map(1..runs, fn _ ->
      {nsec, _} = :timer.tc(fun)
      nsec / 1_000
    end)

  best = Enum.min(times)
  IO.puts("#{name}\t#{size}\t#{Float.round(best, 3)}")
end)
