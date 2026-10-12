defmodule TAlib.Indicators.MACDTest do
  use ExUnit.Case, async: true

  doctest TAlib.Indicators.MACD

  alias TAlib.Indicators.MACD

  # Chronological fixture (the newest-first fixture of earlier releases,
  # reversed; values are unchanged).
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

  test "macd/3" do
    assert Float.round(MACD.macd(@prices), 2) == 20.36
    assert MACD.macd(@prices, 12, 1000) == nil
    assert MACD.macd(@prices, 1000, 26) == nil
    assert MACD.macd(Enum.take(@prices, 51)) == nil
  end

  test "macd_list/3 aligns with the input and ends at the scalar value" do
    series = MACD.macd_list(@prices)
    assert length(series) == length(@prices)
    # MACD defined from index max(fast, slow) - 1.
    assert Enum.count(series, &is_nil/1) == 25
    assert List.last(series) == MACD.macd(@prices)
  end

  test "signal/4" do
    assert Float.round(MACD.signal(@prices), 2) == 12.28
    assert MACD.signal(@prices, 1000) == nil
    # Every MACD value in the signal window must be defined.
    assert MACD.signal(Enum.take(@prices, 68)) == nil
  end

  test "signal/4 applies the given period to the MACD series" do
    period = 5

    expected =
      @prices
      |> MACD.macd_list()
      # scalar-valid MACD values start at index 2 * max(fast, slow) - 1
      |> Enum.drop(51)
      |> Enum.take(-2 * period)
      |> TAlib.Indicators.MA.ema(period)

    assert MACD.signal(@prices, period) == expected
  end

  test "histogram/4" do
    assert Float.round(MACD.histogram(@prices), 2) == 8.08
    assert MACD.histogram(@prices, 12, 26, 1000) == nil
  end

  test "macd_all/4 computes all three values and matches the scalars" do
    all = MACD.macd_all(@prices)

    assert abs(all.macd - MACD.macd(@prices)) < 1.0e-9
    assert abs(all.signal - MACD.signal(@prices)) < 1.0e-9
    assert abs(all.histogram - MACD.histogram(@prices)) < 1.0e-9
    assert abs(all.histogram - (all.macd - all.signal)) < 1.0e-12
  end

  test "macd_all/4 returns per-value nils while data accumulates" do
    # 60 prices: enough for the MACD line (52 needed) but not for the
    # signal line (69 needed).
    partial = MACD.macd_all(Enum.take(@prices, 60))

    assert partial.macd |> is_number()
    assert partial.signal == nil
    assert partial.histogram == nil
  end

  test "periods must be positive integers" do
    assert_raise ArgumentError, fn -> MACD.macd(@prices, 0, 26) end
    assert_raise ArgumentError, fn -> MACD.signal(@prices, 9, 12, 0) end
    assert_raise ArgumentError, fn -> MACD.histogram(@prices, 12, 26, 9.5) end
  end

  test "macd_ext/5 and macd_fix/4" do
    ext = MACD.macd_ext(@prices, 12, 26, 9, :ema)
    assert abs(ext.macd - MACD.macd(@prices)) < 1.0e-9

    sma_ext = MACD.macd_ext(@prices, 12, 26, 9, :sma)
    assert sma_ext.macd |> is_number()
    assert sma_ext.signal |> is_number()

    assert_raise ArgumentError, ~r/unknown MA type/, fn ->
      MACD.macd_ext(@prices, 12, 26, 9, :nope)
    end

    fix = MACD.macd_fix(@prices, 12, 26, 9)
    assert fix.macd |> is_number()
    assert fix.signal |> is_number()
  end
end
