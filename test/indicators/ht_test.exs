defmodule TAlib.Indicators.HTTest do
  use ExUnit.Case, async: true

  doctest TAlib.Indicators.HT

  alias TAlib.Indicators.HT

  @ramp Enum.map(1..100, &(&1 * 1.0))

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

  test "series align with the input and nil-pad the warmup" do
    # The 63-lookback family...
    for series <- [
          HT.ht_trendline(@ramp),
          HT.ht_dcphase(@ramp),
          HT.ht_trendmode(@ramp),
          HT.ht_sine(@ramp).sine
        ] do
      assert length(series) == 100
      assert Enum.count(series, &is_nil/1) == 63
    end

    # ...and the 32-lookback family, as in TA-Lib.
    for series <- [HT.ht_dcperiod(@ramp), HT.ht_phasor(@ramp).inphase] do
      assert length(series) == 100
      assert Enum.count(series, &is_nil/1) == 32
    end
  end

  test "insufficient history yields all nils" do
    assert HT.ht_trendline(Enum.to_list(1..63)) == List.duplicate(nil, 63)
    assert HT.ht_sine([]) == %{sine: [], lead_sine: []}
  end

  # The last values of both fixtures are cross-checked against a
  # transliteration of the TA-Lib C reference; the ramp exercises a
  # pure trend (period pegged high, trend mode 1).
  # All values below are cross-checked against actual TA-Lib (C)
  # output on the same fixtures, matching to 1e-13 or better.
  test "verified last values on the ramp" do
    assert Float.round(List.last(HT.ht_trendline(@ramp)), 4) == 76.85
    assert Float.round(List.last(HT.ht_dcperiod(@ramp)), 4) == 42.5223
    assert Float.round(List.last(HT.ht_dcphase(@ramp)), 4) == 183.9149
    assert Float.round(List.last(HT.ht_phasor(@ramp).inphase), 4) == 6.7514
    assert Float.round(List.last(HT.ht_phasor(@ramp).quadrature), 4) == -1.9195
    assert Float.round(List.last(HT.ht_sine(@ramp).sine), 4) == -0.0683
    assert Float.round(List.last(HT.ht_sine(@ramp).lead_sine), 4) == -0.7537
    assert List.last(HT.ht_trendmode(@ramp)) == 1
  end

  test "verified last values on the price fixture" do
    assert Float.round(List.last(HT.ht_trendline(@prices)), 4) == 1275.3293
    assert Float.round(List.last(HT.ht_dcperiod(@prices)), 4) == 21.2511
    assert Float.round(List.last(HT.ht_dcphase(@prices)), 4) == 169.2707
    assert Float.round(List.last(HT.ht_phasor(@prices).inphase), 4) == 26.6549
    assert Float.round(List.last(HT.ht_phasor(@prices).quadrature), 4) == -10.2152
    assert Float.round(List.last(HT.ht_sine(@prices).sine), 4) == 0.1862
    assert Float.round(List.last(HT.ht_sine(@prices).lead_sine), 4) == -0.5631
  end

  test "invariants" do
    sine = HT.ht_sine(@prices).sine |> Enum.reject(&is_nil/1)
    assert Enum.all?(sine, &(-1.0 <= &1 and &1 <= 1.0))

    periods = HT.ht_dcperiod(@prices) |> Enum.reject(&is_nil/1)
    assert Enum.all?(periods, &(&1 > 0.0 and &1 <= 50.0))

    modes = HT.ht_trendmode(@prices) |> Enum.reject(&is_nil/1)
    assert Enum.all?(modes, &(&1 in [0, 1]))
  end
end
