defmodule TAlib.Indicators.StochasticTest do
  use ExUnit.Case, async: true

  doctest TAlib.Indicators.Stochastic

  alias TAlib.Indicators.Stochastic

  @prices [
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
  ]

  test "stochastic_k/2" do
    assert Stochastic.stochastic_k(@prices, 1000) == nil
    assert Float.round(Stochastic.stochastic_k(@prices), 2) == 90.52
    # Zero-range (flat) windows have an undefined %K.
    assert Stochastic.stochastic_k([5, 5, 5], 3) == nil
  end

  test "stochastic_d/3" do
    assert Stochastic.stochastic_d(@prices, 1000) == nil
    assert Float.round(Stochastic.stochastic_d(@prices), 2) == 95.16
  end

  test "stochastic_d/3 applies d_period to %K" do
    period = 14
    d_period = 5

    k_list =
      Enum.map(0..(d_period - 1), fn x ->
        Stochastic.stochastic_k(Enum.slice(@prices, x, period), period)
      end)

    expected = TAlib.Indicators.MA.sma(k_list, d_period)
    assert abs(Stochastic.stochastic_d(@prices, period, d_period) - expected) < 1.0e-9
  end

  test "periods must be positive integers" do
    assert_raise ArgumentError, fn -> Stochastic.stochastic_k(@prices, 0) end
    assert_raise ArgumentError, fn -> Stochastic.stochastic_d(@prices, 14, 0) end
  end
end
