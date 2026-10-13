# Concurrency panel benchmark: one "symbol" = the 8-indicator set
# below computed over one 100k-point series; the workload is 16 such
# symbols. It measures sequential vs Task.async_stream scaling on the
# BEAM, next to the identical panel run against the TA-Lib Python
# bindings (sequential / threads / processes) by bench_panel.py —
# see docs/BENCHMARKS.md ("Concurrency: the many-symbol panel").
#
#     mix run bench/bench_panel.exs [series-count]

series_count = case System.argv() do
  [n] -> String.to_integer(n)
  _ -> 16
end

size = 100_000

series =
  Enum.map(1..series_count, fn s ->
    Enum.map(0..(size - 1), fn i ->
      100 + 50 * :math.sin(i * 0.03 + s) + rem(i + s, 13) * 0.7 + i * 0.001
    end)
  end)

alias TAlib.Indicators.{ATR, BBands, HT, MA, MACD, MAMA, RSI}

bars_for = fn prices ->
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
end

# The panel: the same jobs as the single-function table, per symbol.
panel = fn prices ->
  bars = bars_for.(prices)

  MA.sma_list(prices, 20)
  MA.ema_list(prices, 20)
  RSI.rsi_list(prices, 14)
  MACD.macd_fix(prices, 12, 26, 9)
  BBands.bbands_list(prices, 20, 2)
  ATR.atr_list(bars, 14)
  HT.ht_trendline(prices)
  MAMA.mama(prices, 0.5, 0.05)

  :ok
end

schedulers = System.schedulers_online()

run_sequential = fn ->
  Enum.each(series, panel)
  :ok
end

run_parallel = fn ->
  series
  |> Task.async_stream(panel, max_concurrency: schedulers, timeout: :infinity)
  |> Stream.run()
end

median = fn runs, fun ->
  times =
    Enum.map(1..runs, fn _ ->
      {nsec, _} = :timer.tc(fun)
      nsec / 1_000
    end)

  Enum.sort(times) |> Enum.at(div(length(times), 2))
end

# Warmup once, then the median of repeated runs.
Enum.each(series, panel)

seq = median.(3, run_sequential)
par = median.(3, run_parallel)

IO.puts("panel-sequential\t#{series_count}x#{size}\t#{Float.round(seq, 1)}")
IO.puts("panel-parallel\t#{series_count}x#{size}\t#{Float.round(par, 1)}")
IO.puts("schedulers\t#{schedulers}")
IO.puts("speedup\t#{Float.round(seq / par, 2)}")
