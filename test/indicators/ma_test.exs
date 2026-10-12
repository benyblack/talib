defmodule TAlib.Indicators.MATest do
  use ExUnit.Case, async: true

  doctest TAlib.Indicators.MA

  alias TAlib.Indicators.MA

  # Chronological series (oldest first) — the single input convention.
  @series [
    44.3289,
    44.3189,
    44.3389,
    44.0902,
    44.1497,
    43.6124,
    44.3278,
    44.8264,
    45.0955,
    45.4245,
    45.8433,
    46.0826,
    45.8931,
    46.0328,
    45.614,
    46.282
  ]

  # The 100-price fixture from earlier releases was newest-first; it is
  # reversed here into chronological order (values are unchanged).
  @prices Enum.reverse([
            1330.95,
            1334.65,
            1340,
            1338.7,
            1319.6,
            1305.75,
            1303.8,
            1309.6,
            1296.95,
            1254.25,
            1266.2,
            1266,
            1270.7,
            1244.55,
            1233.7,
            1244.5,
            1227.05,
            1225.05,
            1235.75,
            1246.55,
            1248.3,
            1245.7,
            1250.5,
            1242.95,
            1228.5,
            1246.9,
            1258.2,
            1250.2,
            1253.15,
            1233.8,
            1255.15,
            1266.5,
            1259.9,
            1257.75,
            1273.3,
            1272.2,
            1272.3,
            1264.65,
            1258.9,
            1235.15,
            1254.6,
            1258.35,
            1293.2,
            1309.15,
            1281.1,
            1276.1,
            1286.7,
            1287.45,
            1293.2,
            1307.35,
            1345.6,
            1300.6,
            1299.6,
            1299.4,
            1301.8,
            1303.65,
            1308.95,
            1319.25,
            1319.2,
            1336.75,
            1313.3,
            1309,
            1295.3,
            1302.15,
            1302.7,
            1314.15,
            1334.1,
            1333.95,
            1399.65,
            1430.1,
            1438.65,
            1429.9,
            1399.95,
            1396.75,
            1395.9,
            1378.35,
            1372.7,
            1382.05,
            1389.2,
            1408.7,
            1386.3,
            1399.1,
            1356,
            1348.7,
            1345.35,
            1341.2,
            1342.7,
            1350.7,
            1322.9,
            1291.65,
            1287.65,
            1297.7,
            1307.4,
            1308.05,
            1305.15,
            1306.95,
            1318.15,
            1317.55,
            1279.15,
            1208.2
          ])

  test "sma/2" do
    assert MA.sma(@series, 50) == nil
    assert MA.sma(@series) == nil
    assert Float.round(MA.sma(@series, 10), 4) == 45.5422
    assert Float.round(MA.sma([1281.90, 1277.90, 1289.80, 1297.00, 1304.70], 4), 2) == 1292.35
  end

  test "sma_list/2 returns a nil-padded rolling series" do
    assert round4(MA.sma_list(@series, 3)) == [
             nil,
             nil,
             44.3289,
             44.2493,
             44.1929,
             43.9508,
             44.03,
             44.2555,
             44.7499,
             45.1155,
             45.4544,
             45.7835,
             45.9397,
             46.0028,
             45.8466,
             45.9763
           ]
  end

  test "sma_list/2 agrees with sma/2 at the latest point" do
    assert abs(List.last(MA.sma_list(@series, 10)) - MA.sma(@series, 10)) < 1.0e-9
  end

  test "sma_list/2 and ema_list/2 return [] for empty input" do
    assert MA.sma_list([], 3) == []
    assert MA.ema_list([], 3) == []
  end

  test "update_sma/4 matches recomputing the window" do
    period = 10
    current = MA.sma(@series, period)
    new_value = 46.5
    shifted = Enum.take(@series ++ [new_value], -period)

    updated = MA.update_sma(@series, current, new_value, period)
    assert abs(updated - MA.sma(shifted, period)) < 1.0e-9
  end

  test "update_sma/4 returns nil with insufficient history" do
    assert MA.update_sma([1, 2], 1.5, 3, 5) == nil
  end

  test "cma/1 is the mean of all prices" do
    assert MA.cma([]) == nil
    assert Float.round(MA.cma(@series), 4) == 45.0163
  end

  test "cma_list/1 is the running mean" do
    cmas = MA.cma_list(@series)
    assert length(cmas) == length(@series)
    assert Float.round(hd(cmas), 4) == 44.3289
    assert abs(List.last(cmas) - MA.cma(@series)) < 1.0e-9
  end

  test "update_cma/3" do
    assert MA.update_cma(44.4513, 44, 4) == 44.36104
  end

  test "wma/2 weights the newest price highest" do
    assert MA.wma(@series, 50) == nil
    assert MA.wma(@series) == nil
    assert Float.round(MA.wma(@series, 10), 4) == 45.8098
  end

  test "wma_list/2 agrees with wma/2 at the latest point" do
    assert abs(List.last(MA.wma_list(@series, 10)) - MA.wma(@series, 10)) < 1.0e-9
  end

  test "ema/2" do
    assert MA.ema(@series, 50) == nil
    assert Float.round(MA.ema(@prices, 5), 2) == 1328.45
    assert Float.round(MA.ema(@prices, 13), 2) == 1306.72
  end

  test "ema_list/2 returns a nil-padded EMA series" do
    assert round4(MA.ema_list(@series, 3)) == [
             nil,
             nil,
             44.3289,
             44.2096,
             44.1796,
             43.896,
             44.1119,
             44.4692,
             44.7823,
             45.1034,
             45.4734,
             45.778,
             45.8355,
             45.9342,
             45.7741,
             46.028
           ]
  end

  test "ema_list/2 agrees exactly with ema/2 at the latest point" do
    assert MA.ema(@series, 3) == List.last(MA.ema_list(@series, 3))
  end

  test "rma/2 and rma_list/2 (Wilder smoothing)" do
    assert MA.rma(@series, 50) == nil
    assert Float.round(MA.rma(@prices, 14), 4) == 1288.0976

    rmas = MA.rma_list(@prices, 14)
    assert length(rmas) == length(@prices)
    assert Enum.count(rmas, &is_nil/1) == 13
    assert MA.rma(@prices, 14) == List.last(rmas)
  end

  test "periods must be positive integers" do
    assert_raise ArgumentError, ~r/positive integer/, fn -> MA.sma(@series, 0) end
    assert_raise ArgumentError, fn -> MA.ema(@series, -3) end
    assert_raise ArgumentError, fn -> MA.wma(@series, 2.5) end
    assert_raise ArgumentError, fn -> MA.sma_list(@series, 0) end
  end

  defp round4(list) do
    Enum.map(list, fn
      nil -> nil
      x -> Float.round(x, 4)
    end)
  end

  test "overlap additions: dema, tema, trima, kama, t3, midpoint" do
    assert Float.round(MA.dema(@prices, 14), 4) == 1207.6279
    assert Float.round(MA.tema(@prices, 14), 4) == 1292.6967
    assert Float.round(MA.trima(@prices, 14), 4) == 1300.0545
    assert Float.round(MA.kama(@prices, 14), 4) == 1314.0551
    assert Float.round(MA.t3(@prices, 14), 4) == 1359.9818
    assert Float.round(MA.midpoint(@prices, 14), 4) == 1292.275

    assert length(MA.dema_list(@prices, 14)) == length(@prices)
    assert Enum.count(MA.t3_list(@prices, 14), &is_nil/1) == 6 * (14 - 1)
  end

  test "ma/3 dispatcher and mavp/5" do
    assert MA.ma(@series, 3, :sma) == MA.sma(@series, 3)
    assert MA.ma(@series, 3, :ema) == MA.ema(@series, 3)
    assert_raise ArgumentError, ~r/unknown MA type/, fn -> MA.ma(@series, 3, :nope) end

    assert MA.mavp([1, 2, 3, 4, 5, 6], [2, 2, 2, 2, 2, 2]) |> List.last() == 5.5
    assert MA.mavp([1, 2, 3, 4, 5, 6], [1, 2, 3, 4, 5, 6]) |> Enum.take(3) == [nil, 1.5, 2.0]
  end
end
