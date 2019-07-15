defmodule TAlib.Tests.MaTests do
  use ExUnit.Case
  alias TAlib.Indicators.MA

  @prices [
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

  @prices2 [1330.95, 1334.65, 1340, 1338.7, 1319.6, 1305.75, 1303.8, 1309.6, 1296.95, 1254.25, 1266.2, 1266, 1270.7, 1244.55, 1233.7, 1244.5, 1227.05, 1225.05, 1235.75, 1246.55, 1248.3, 1245.7, 1250.5, 1242.95, 1228.5, 1246.9, 1258.2, 1250.2, 1253.15, 1233.8, 1255.15, 1266.5, 1259.9, 1257.75, 1273.3, 1272.2, 1272.3, 1264.65, 1258.9, 1235.15, 1254.6, 1258.35, 1293.2, 1309.15, 1281.1, 1276.1, 1286.7, 1287.45, 1293.2, 1307.35, 1345.6, 1300.6, 1299.6, 1299.4, 1301.8, 1303.65, 1308.95, 1319.25, 1319.2, 1336.75, 1313.3, 1309, 1295.3, 1302.15, 1302.7, 1314.15, 1334.1, 1333.95, 1399.65, 1430.1, 1438.65, 1429.9, 1399.95, 1396.75, 1395.9, 1378.35, 1372.7, 1382.05, 1389.2, 1408.7, 1386.3, 1399.1, 1356, 1348.7, 1345.35, 1341.2, 1342.7, 1350.7, 1322.9, 1291.65, 1287.65, 1297.7, 1307.4, 1308.05, 1305.15, 1306.95, 1318.15, 1317.55, 1279.15, 1208.2]

  test "Calculate SMA list" do
    rounded = Enum.map(MA.sma_list(@prices, 3), fn
      nil -> nil
      x ->
      Float.round(x, 4)
    end)
    assert  rounded == [nil, nil, 44.3289, 44.2493, 44.1929,
    43.9508, 44.03, 44.2555, 44.7499, 45.1155,
    45.4544, 45.7835, 45.9397, 46.0028, 45.8466,
    45.9763]
  end

  test "calculate SMA" do
    assert MA.sma(@prices, 50) == nil
    assert MA.sma(@prices) == nil #default period is 50
    assert Float.round(MA.sma(@prices, 10), 4) == 44.4513
    assert Float.round(MA.sma([1304.70, 1297.00, 1289.80, 1277.90, 1281.90], 4), 2) == 1292.35

    assert Float.round(MA.update_sma(@prices, 44.6028, 46.0826, 10), 4) == 44.6028
  end

  test "calculate CMA" do
    assert MA.cma(@prices, 50) == 0
    assert MA.cma(@prices) == 0 #default period is 50
    assert Float.round(MA.cma(@prices, 10), 4) == 44.4513

    assert MA.update_cma(44.4513,44, 4) == 44.36104

  end

  test "calculate WMA" do
    assert MA.wma(@prices, 50) == 0
    assert MA.wma(@prices) == 0 #default period is 50
    assert Float.round(MA.wma([0,1,2,3], 3), 4) == 1.3333
    assert Float.round(MA.wma(@prices, 10), 4) == 44.6141
  end

  test "calculate EMA" do
    assert MA.ema(@prices, 50) == 0
    assert Float.round(MA.ema(@prices2, 5), 2) == 1328.45
    assert Float.round(MA.ema(@prices2, 13), 2) == 1306.72

    assert Float.round(MA.update_ema(1306.72, 1300, 50), 4) == 1306.4565
  end
end
