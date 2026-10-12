defmodule TAlib.Indicators.ADXTest do
  use ExUnit.Case, async: true

  doctest TAlib.Indicators.ADX

  alias TAlib.Indicators.ADX

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

  @bars Enum.with_index(@prices)
        |> Enum.map(fn {price, i} ->
          %{
            high: price + 1 + rem(i, 3),
            low: price - 1 - rem(i + 1, 3),
            close: price,
            volume: 1000 + 100 * rem(i, 5)
          }
        end)

  test "plus_di/2 and minus_di/2" do
    assert ADX.plus_di(@bars, 200) == nil
    assert ADX.minus_di(@bars, 200) == nil
    assert Float.round(ADX.plus_di(@bars, 14), 4) == 55.353
    assert Float.round(ADX.minus_di(@bars, 14), 4) == 28.8769
  end

  test "adx/2 needs 2 * period - 1 bars" do
    assert ADX.adx(Enum.take(@bars, 26), 14) == nil
    assert Float.round(ADX.adx(@bars, 14), 4) == 21.3288
  end

  test "adx_all/3 computes all three values and matches the scalars" do
    all = ADX.adx_all(@bars, 14)

    assert abs(all.plus_di - ADX.plus_di(@bars, 14)) < 1.0e-9
    assert abs(all.minus_di - ADX.minus_di(@bars, 14)) < 1.0e-9
    assert abs(all.adx - ADX.adx(@bars, 14)) < 1.0e-9
  end

  test "adx_all/3 returns per-value nils while data accumulates" do
    # 20 bars: enough for the directional lines (14 needed) but not for
    # ADX (27 needed).
    partial = ADX.adx_all(Enum.take(@bars, 20), 14)

    assert partial.plus_di |> is_number()
    assert partial.minus_di |> is_number()
    assert partial.adx == nil
  end

  test "periods must be positive integers" do
    assert_raise ArgumentError, ~r/positive integer/, fn -> ADX.adx(@bars, 0) end
    assert_raise ArgumentError, fn -> ADX.plus_di(@bars, -1) end
    assert_raise ArgumentError, fn -> ADX.adx_all(@bars, 1.5) end
  end

  test "dx/2, adxr/2 and the raw DM series" do
    assert Float.round(ADX.dx(@bars, 14), 4) == 31.4331
    assert ADX.adxr(Enum.take(@bars, 39), 14) == nil
    assert Float.round(ADX.adxr(@bars, 14), 4) == 17.6999

    plus = ADX.plus_dm(@bars)
    minus = ADX.minus_dm(@bars)
    assert length(plus) == length(@bars) and hd(plus) == 0
    assert length(minus) == length(@bars) and hd(minus) == 0
  end
end
