defmodule TAlib.Indicators.BBandsTest do
  use ExUnit.Case, async: true

  doctest TAlib.Indicators.BBands

  alias TAlib.Indicators.BBands

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

  test "bbands/3" do
    assert BBands.bbands(@prices, 200, 2) == nil
    assert BBands.bbands(@prices, 200) == nil

    bands = BBands.bbands(@prices, 20, 2)
    assert abs(bands.upper - 1358.82) < 0.01
    assert abs(bands.middle - 1279.71) < 0.01
    assert abs(bands.lower - 1200.61) < 0.01
  end

  test "bbands_list/3 aligns with the input and ends at the scalar bands" do
    series = BBands.bbands_list(@prices, 20, 2)
    assert length(series) == length(@prices)
    assert Enum.count(series, &is_nil/1) == 19

    last = List.last(series)
    scalar = BBands.bbands(@prices, 20, 2)
    assert abs(last.upper - scalar.upper) < 1.0e-9
    assert abs(last.middle - scalar.middle) < 1.0e-9
    assert abs(last.lower - scalar.lower) < 1.0e-9
  end

  test "a constant series collapses onto the SMA" do
    bands = BBands.bbands(List.duplicate(5, 4), 4, 2)
    assert bands == %{upper: 5.0, middle: 5.0, lower: 5.0}
  end

  test "periods must be positive integers and mult a number" do
    assert_raise ArgumentError, ~r/positive integer/, fn -> BBands.bbands(@prices, 0) end
    assert_raise ArgumentError, ~r/mult/, fn -> BBands.bbands(@prices, 20, :two) end
  end
end
