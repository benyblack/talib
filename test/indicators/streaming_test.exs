defmodule TAlib.StreamingTest do
  use ExUnit.Case, async: true

  alias TAlib.Indicators.{
    ATR,
    Aroon,
    BBands,
    Donchian,
    MA,
    MACD,
    RSI,
    StdDev,
    Stochastic,
    WilliamsR
  }

  # Deterministic fixtures (different from the audit fixtures): a
  # smooth trend with jitter for price-based indicators, and LCG bars
  # for the bar-based ones.
  @prices for i <- 0..319,
              do: 100.0 + 50.0 * :math.sin(i * 0.03 + 1.3) + rem(i + 1, 13) * 0.7 + i * 0.001

  {bars_fixture, _} =
    Enum.map_reduce(0..319, 12_345, fn _i, s ->
      u1 = rem(s * 1_103_515_245 + 12_345, 2_147_483_648)
      u2 = rem(u1 * 1_103_515_245 + 12_345, 2_147_483_648)
      u3 = rem(u2 * 1_103_515_245 + 12_345, 2_147_483_648)
      u4 = rem(u3 * 1_103_515_245 + 12_345, 2_147_483_648)

      open = 100.0 + rem(u1, 5001) / 10.0
      close = open + (rem(u2, 4001) - 2000) / 100.0

      bar = %{
        high: max(open, close) + rem(u3, 2001) / 100.0,
        low: min(open, close) - rem(u4, 2001) / 100.0,
        close: close
      }

      {bar, u4}
    end)

  @bars bars_fixture

  # Warm up on the first 300 points, stream the remaining 20, and
  # return the full streamed series — which must equal the batch
  # series over all 320 points bit for bit.
  defp stream(history, rest, init, next) do
    {state, values} = init.(history)

    {state, ext} =
      Enum.reduce(rest, {state, []}, fn x, {state, acc} ->
        {state, value} = next.(state, x)
        {state, [value | acc]}
      end)

    values ++ Enum.reverse(ext)
  end

  defp stream_prices(init, next),
    do: stream(Enum.take(@prices, 300), Enum.drop(@prices, 300), init, next)

  defp stream_bars(init, next),
    do: stream(Enum.take(@bars, 300), Enum.drop(@bars, 300), init, next)

  describe "streaming continues the batch series bit for bit" do
    test "sma (including period 1)" do
      assert stream_prices(&MA.sma_init(&1, 14), &MA.sma_next/2) == MA.sma_list(@prices, 14)
      assert stream_prices(&MA.sma_init(&1, 1), &MA.sma_next/2) == MA.sma_list(@prices, 1)
    end

    test "ema" do
      assert stream_prices(&MA.ema_init(&1, 12), &MA.ema_next/2) == MA.ema_list(@prices, 12)
    end

    test "wma" do
      assert stream_prices(&MA.wma_init(&1, 7), &MA.wma_next/2) == MA.wma_list(@prices, 7)
    end

    test "rma" do
      assert stream_prices(&MA.rma_init(&1, 9), &MA.rma_next/2) == MA.rma_list(@prices, 9)
    end

    test "std_dev" do
      assert stream_prices(&StdDev.init(&1, 20), &StdDev.next/2) ==
               StdDev.std_dev_list(@prices, 20)
    end

    test "bbands" do
      assert stream_prices(&BBands.init(&1, 20, 2.0), &BBands.next/2) ==
               BBands.bbands_list(@prices, 20, 2.0)
    end

    test "rsi" do
      assert stream_prices(&RSI.init(&1, 14), &RSI.next/2) == RSI.rsi_list(@prices, 14)
    end

    test "atr" do
      assert stream_bars(&ATR.init(&1, 14), &ATR.next/2) == ATR.atr_list(@bars, 14)
    end

    test "stochastic fast %K" do
      assert stream_prices(&Stochastic.k_init(&1, 14), &Stochastic.k_next/2) ==
               Stochastic.stochastic_k_list(@prices, 14)
    end

    test "stochastic slow (%K and %D)" do
      {state, values} = Stochastic.slow_init(Enum.take(@prices, 300), 14, 5, 3)

      {_state, ext} =
        Enum.reduce(Enum.drop(@prices, 300), {state, []}, fn price, {state, acc} ->
          {state, value} = Stochastic.slow_next(state, price)
          {state, [value | acc]}
        end)

      k = (values.k ++ Enum.map(Enum.reverse(ext), & &1.k)) |> Enum.reject(&is_nil/1)
      d = (values.d ++ Enum.map(Enum.reverse(ext), & &1.d)) |> Enum.reject(&is_nil/1)

      expected_k =
        @prices
        |> Stochastic.stochastic_k_list(14)
        |> Enum.reject(&is_nil/1)
        |> MA.sma_list(5)
        |> Enum.reject(&is_nil/1)

      expected_d = expected_k |> MA.sma_list(3) |> Enum.reject(&is_nil/1)

      assert k == expected_k
      assert d == expected_d
    end

    test "williams %R" do
      assert stream_prices(&WilliamsR.init(&1, 14), &WilliamsR.next/2) ==
               WilliamsR.williams_r_list(@prices, 14)
    end

    test "aroon" do
      assert stream_prices(&Aroon.init(&1, 14), &Aroon.next/2) == Aroon.aroon_list(@prices, 14)
    end

    test "donchian" do
      assert stream_bars(&Donchian.init(&1, 20), &Donchian.next/2) ==
               Donchian.donchian_list(@bars, 20)
    end

    test "macd (line, signal, histogram)" do
      {state, values} = MACD.init(Enum.take(@prices, 200), 12, 26, 9)

      {_state, ext} =
        Enum.reduce(Enum.drop(@prices, 200), {state, []}, fn price, {state, acc} ->
          {state, value} = MACD.next(state, price)
          {state, [value | acc]}
        end)

      macd = values.macd ++ Enum.map(Enum.reverse(ext), & &1.macd)
      signal = values.signal ++ Enum.map(Enum.reverse(ext), & &1.signal)
      histogram = values.histogram ++ Enum.map(Enum.reverse(ext), & &1.histogram)

      assert macd == MACD.macd_list(@prices, 12, 26)

      expected_signal =
        @prices
        |> MACD.macd_list(12, 26)
        |> Enum.reject(&is_nil/1)
        |> MA.ema_list(9)
        |> Enum.reject(&is_nil/1)

      assert Enum.reject(signal, &is_nil/1) == expected_signal

      fix = MACD.macd_fix(@prices, 12, 26, 9)
      assert List.last(macd) == fix.macd
      assert List.last(signal) == fix.signal
      assert List.last(histogram) == fix.histogram
    end
  end

  describe "edge cases" do
    test "insufficient history raises ArgumentError" do
      assert_raise ArgumentError, fn -> MA.sma_init(Enum.to_list(1..4), 5) end
      assert_raise ArgumentError, fn -> RSI.init(Enum.to_list(1..14), 14) end
      assert_raise ArgumentError, fn -> ATR.init(Enum.take(@bars, 14), 14) end
      assert_raise ArgumentError, fn -> MACD.init(Enum.to_list(1..30), 12, 26, 9) end
      assert_raise ArgumentError, fn -> Stochastic.slow_init(Enum.to_list(1..4), 3, 2, 2) end
      assert_raise ArgumentError, fn -> Aroon.init(Enum.to_list(1..3), 3) end
    end

    test "invalid periods raise ArgumentError" do
      assert_raise ArgumentError, fn -> MA.sma_init([1, 2, 3], 0) end
      assert_raise ArgumentError, fn -> StdDev.init([1, 2, 3], -1) end
    end

    @tag :flat_windows
    test "flat windows: %K and %R nil, smoothers skip" do
      # Rising, then one pop, then perfectly flat: %K defined at the
      # pop, undefined (nil) while flat — and the slow smoothers skip
      # the flat bars exactly like the batch reject does.
      prices = Enum.to_list(1..20) ++ [30] ++ List.duplicate(30, 15)

      assert stream(
               Enum.take(prices, 30),
               Enum.drop(prices, 30),
               &Stochastic.k_init(&1, 5),
               &Stochastic.k_next/2
             ) ==
               Stochastic.stochastic_k_list(prices, 5)

      assert stream(
               Enum.take(prices, 30),
               Enum.drop(prices, 30),
               &WilliamsR.init(&1, 5),
               &WilliamsR.next/2
             ) ==
               WilliamsR.williams_r_list(prices, 5)

      {state, values} = Stochastic.slow_init(Enum.take(prices, 30), 5, 3, 3)

      {_state, ext} =
        Enum.reduce(Enum.drop(prices, 30), {state, []}, fn price, {state, acc} ->
          {state, value} = Stochastic.slow_next(state, price)
          {state, [value | acc]}
        end)

      k = (values.k ++ Enum.map(Enum.reverse(ext), & &1.k)) |> Enum.reject(&is_nil/1)
      d = (values.d ++ Enum.map(Enum.reverse(ext), & &1.d)) |> Enum.reject(&is_nil/1)

      expected_k =
        prices
        |> Stochastic.stochastic_k_list(5)
        |> Enum.reject(&is_nil/1)
        |> MA.sma_list(3)
        |> Enum.reject(&is_nil/1)

      expected_d = expected_k |> MA.sma_list(3) |> Enum.reject(&is_nil/1)

      assert k == expected_k
      assert d == expected_d
    end

    test "RSI returns nil on a window with no movement at all" do
      prices = Enum.to_list(1..20) ++ List.duplicate(20, 15)

      assert stream(Enum.take(prices, 30), Enum.drop(prices, 30), &RSI.init(&1, 5), &RSI.next/2) ==
               RSI.rsi_list(prices, 5)
    end

    test "equal extremes: earliest tie wins, like the batch window walk" do
      # Two equal highs inside the window; the aroon/donchian/midpoint
      # batch walks keep the earliest occurrence.
      prices = [3, 9, 9, 4, 5, 6, 9, 2, 7, 9, 1, 8, 9, 9, 4, 6, 9, 3, 5, 9, 2, 8, 9, 4]

      assert stream(
               Enum.take(prices, 20),
               Enum.drop(prices, 20),
               &Aroon.init(&1, 4),
               &Aroon.next/2
             ) ==
               Aroon.aroon_list(prices, 4)

      assert stream(
               Enum.take(prices, 20),
               Enum.drop(prices, 20),
               &Stochastic.k_init(&1, 4),
               &Stochastic.k_next/2
             ) ==
               Stochastic.stochastic_k_list(prices, 4)
    end
  end
end
