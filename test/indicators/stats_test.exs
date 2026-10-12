defmodule TAlib.Indicators.StatsTest do
  use ExUnit.Case, async: true

  doctest TAlib.Indicators.Stats

  alias TAlib.Indicators.Stats

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

  @market Enum.with_index(@prices)
          |> Enum.map(fn {price, i} -> price + 20 * :math.sin(0.3 * i) end)

  test "variance/2" do
    assert Stats.variance(@prices, 200) == nil
    assert Float.round(Stats.variance(@prices, 14), 4) == 1006.4367
  end

  test "linear regression family" do
    assert Stats.linear_reg(@prices, 200) == nil

    assert Float.round(Stats.slope(@prices, 14), 4) == 7.3571
    assert Float.round(Stats.intercept(@prices, 14), 4) == 1250.8714
    assert Float.round(Stats.linear_reg(@prices, 14), 4) == 1346.5143
    assert Float.round(Stats.tsf(@prices, 14), 4) == 1353.8714
    assert Float.round(Stats.angle(@prices, 14), 4) == 82.2597
  end

  test "beta/3 and correl/3" do
    assert Stats.beta(@prices, @market, 14) |> Float.round(4) == 0.6104
    assert Stats.correl(@prices, @market, 14) |> Float.round(4) == 0.938

    # A perfectly linear relation has correlation 1 and known beta.
    assert Stats.correl([1, 2, 3, 4], [2, 4, 6, 8], 3) == 1.0
    assert Stats.beta([1, 2, 3, 4], [2, 4, 6, 8], 3) == 2.0
  end

  test "periods must be positive integers" do
    assert_raise ArgumentError, ~r/positive integer/, fn -> Stats.variance(@prices, 0) end
    assert_raise ArgumentError, fn -> Stats.slope(@prices, -1) end
  end
end
