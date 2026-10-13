# Streaming benchmark: the per-tick cost of the `init`/`next` API vs
# recomputing the batch series, printed as JSON lines in the style of
# bench/bench.exs.
#
#     mix run bench/bench_stream.exs [size]
#
# Dependency-free: one `:timer.tc` around a fold of `ticks` new prices
# through each warmed state, reported per tick in microseconds, next
# to the batch cost of the same series (what a per-tick recompute
# would pay) and the one-time `init` warm-up.

size = case System.argv() do
  [n] -> String.to_integer(n)
  _ -> 100_000
end

ticks_count = 10_000

prices =
  Enum.map(0..(size + ticks_count - 1), fn i ->
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

alias TAlib.Indicators.{Aroon, ATR, BBands, Donchian, MA, MACD, RSI, StdDev, Stochastic, WilliamsR}

history_prices = Enum.take(prices, size)
history_bars = Enum.take(bars, size)
tick_prices = Enum.drop(prices, size)
tick_bars = Enum.drop(bars, size)

# {label, init over history, next/2}
streams = [
  {"MA.sma_next/2 (20)", fn -> MA.sma_init(history_prices, 20) end, &MA.sma_next/2},
  {"MA.ema_next/2 (20)", fn -> MA.ema_init(history_prices, 20) end, &MA.ema_next/2},
  {"MA.wma_next/2 (20)", fn -> MA.wma_init(history_prices, 20) end, &MA.wma_next/2},
  {"MA.rma_next/2 (20)", fn -> MA.rma_init(history_prices, 20) end, &MA.rma_next/2},
  {"StdDev.next/2 (20)", fn -> StdDev.init(history_prices, 20) end, &StdDev.next/2},
  {"BBands.next/2 (20,2)", fn -> BBands.init(history_prices, 20, 2) end, &BBands.next/2},
  {"RSI.next/2 (14)", fn -> RSI.init(history_prices, 14) end, &RSI.next/2},
  {"ATR.next/2 (14) [bars]", fn -> ATR.init(history_bars, 14) end, &ATR.next/2},
  {"MACD.next/2 (12/26/9)", fn -> MACD.init(history_prices, 12, 26, 9) end, &MACD.next/2},
  {"Stochastic.k_next/2 (14)", fn -> Stochastic.k_init(history_prices, 14) end, &Stochastic.k_next/2},
  {"Stochastic.slow_next/2 (14,5,3)", fn -> Stochastic.slow_init(history_prices, 14, 5, 3) end, &Stochastic.slow_next/2},
  {"WilliamsR.next/2 (14)", fn -> WilliamsR.init(history_prices, 14) end, &WilliamsR.next/2},
  {"Donchian.next/2 (20) [bars]", fn -> Donchian.init(history_bars, 20) end, &Donchian.next/2},
  {"Aroon.next/2 (14)", fn -> Aroon.init(history_prices, 14) end, &Aroon.next/2}
]

Enum.each(streams, fn {label, init, next} ->
  {state, _} = init.()
  inputs = if String.contains?(label, "[bars]"), do: tick_bars, else: tick_prices

  # Warm-up fold, then the best of 5 measured folds.
  Enum.reduce(inputs, state, fn x, st -> elem(next.(st, x), 0) end)

  per_tick =
    Enum.map(1..5, fn _ ->
      {state, _} = init.()

      {us, _} =
        :timer.tc(fn ->
          Enum.reduce(inputs, state, fn x, st -> elem(next.(st, x), 0) end)
        end)

      # :timer.tc reports microseconds; one fold is `ticks_count` ticks.
      us / ticks_count
    end)
    |> Enum.min()
    |> Float.round(4)

  IO.puts("#{label}\tper-tick-us\t#{per_tick}")
end)

IO.puts("")

# What a per-tick recompute would pay: the full batch series at `size`,
# and the one-time warm-up cost of `init`.
recomputes = [
  {"MA.sma_list/2 (20)", fn -> MA.sma_list(history_prices, 20) end},
  {"BBands.bbands_list/3 (20,2)", fn -> BBands.bbands_list(history_prices, 20, 2) end},
  {"RSI.rsi_list/2 (14)", fn -> RSI.rsi_list(history_prices, 14) end},
  {"ATR.atr_list/2 (14) [bars]", fn -> ATR.atr_list(history_bars, 14) end},
  {"MACD.macd_fix/4 (12/26/9)", fn -> MACD.macd_fix(history_prices, 12, 26, 9) end},
  {"Donchian.donchian_list/2 (20) [bars]", fn -> Donchian.donchian_list(history_bars, 20) end},
  {"Aroon.aroon_list/2 (14)", fn -> Aroon.aroon_list(history_prices, 14) end}
]

Enum.each(recomputes, fn {label, fun} ->
  fun.()

  ms =
    Enum.map(1..5, fn _ ->
      {us, _} = :timer.tc(fun)
      us / 1_000
    end)
    |> Enum.min()
    |> Float.round(3)

  IO.puts("#{label}\trecompute-ms\t#{ms}")
end)

IO.puts("")

inits = [
  {"MA.sma_init/2 (20)", fn -> MA.sma_init(history_prices, 20) end},
  {"RSI.init/2 (14)", fn -> RSI.init(history_prices, 14) end},
  {"MACD.init/4 (12/26/9)", fn -> MACD.init(history_prices, 12, 26, 9) end},
  {"Stochastic.slow_init/4 (14,5,3)", fn -> Stochastic.slow_init(history_prices, 14, 5, 3) end}
]

Enum.each(inits, fn {label, fun} ->
  fun.()

  ms =
    Enum.map(1..5, fn _ ->
      {us, _} = :timer.tc(fun)
      us / 1_000
    end)
    |> Enum.min()
    |> Float.round(3)

  IO.puts("#{label}\twarmup-ms\t#{ms}")
end)
