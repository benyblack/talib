defmodule TAlib.Indicators.RSITest do
  use ExUnit.Case, async: true

  doctest TAlib.Indicators.RSI

  alias TAlib.Indicators.RSI

  # All fixtures are chronological, oldest first (the fixtures of earlier
  # releases were newest-first and have been reversed; values unchanged).
  @prices Enum.reverse([
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
            46.282,
            46.28
          ])

  @prices3 Enum.reverse([
             46.28,
             46.28,
             45.61,
             46.03,
             45.89,
             46.08,
             45.84,
             45.42,
             45.10,
             44.83,
             44.33,
             43.61,
             44.15,
             44.09,
             44.34
           ])

  @prices2 Enum.reverse([
             70.369,
             70.001,
             69.745,
             68.204,
             67.923,
             67.878,
             67.99,
             67.232,
             66.935,
             67.642,
             68.199,
             67.642,
             67.385,
             66.973,
             67.113,
             67.592,
             66.743,
             66.494,
             65.585,
             65.91,
             65.795
           ])

  test "rsi_list/2 returns a nil-padded RSI series" do
    data = Enum.to_list(1..100)

    expected = List.duplicate(nil, 14) ++ List.duplicate(100.0, 86)
    assert RSI.rsi_list(data, 14) == expected
  end

  test "rsi_list/2 returns [] for empty input and nils for flat data" do
    assert RSI.rsi_list([], 14) == []
    assert RSI.rsi_list([5, 5, 5, 5, 5], 3) == [nil, nil, nil, nil, nil]
  end

  test "rsi_list/2 agrees with rsi/2 at the latest point" do
    assert abs(List.last(RSI.rsi_list(@prices3, 14)) - RSI.rsi(@prices3)) < 1.0e-9
  end

  test "rsi/2" do
    # Compared with https://www.marketvolume.com/quotes/calculatersi.asp
    assert Float.round(RSI.rsi(@prices3), 2) == 70.46
    assert Float.round(RSI.rsi(@prices2), 2) == 75.89
    assert RSI.rsi([], 14) == nil
    assert RSI.rsi([1, 2, 3], 14) == nil
    # A flat window has no relative strength: RSI is undefined.
    assert RSI.rsi([5, 5, 5, 5, 5], 4) == nil
  end

  test "rsi/2 requires a positive integer period" do
    assert_raise ArgumentError, fn -> RSI.rsi(@prices, 0) end
    assert_raise ArgumentError, fn -> RSI.rsi_list([1, 2, 3], -1) end
  end

  test "average_loss/2" do
    assert RSI.average_loss([40, 30, 20, 10], 3) == 10
    assert RSI.average_loss([1, 2, 3]) == 0
    assert RSI.average_loss([]) == 0
    assert Float.round(RSI.average_loss(@prices), 4) == 0.1921
    assert RSI.average_loss([4, 3, 2, 1], 2) == 1
    # A single price has no change to average.
    assert RSI.average_loss([5], 3) == 0.0
  end

  test "average_gain/2" do
    assert RSI.average_gain([0, 10, 20, 30], 3) == 10
    assert RSI.average_gain([]) == 0
    assert Float.round(RSI.average_gain(@prices), 2) == 0.10
    assert RSI.average_gain([1, 2, 3, 4], 2) == 1
    # A single price has no change to average.
    assert RSI.average_gain([5], 3) == 0.0
  end

  test "gain/1" do
    assert RSI.gain([0, 10, 20, 30]) == 30
    assert RSI.gain([]) == 0
    assert RSI.gain([1, 2, 3, 4]) == 3
    assert Float.round(RSI.gain(@prices3), 2) == 3.34
  end

  test "loss/1" do
    assert RSI.loss([40, 30, 20, 10]) == 30
    assert RSI.loss([1, 2, 3]) == 0
    assert RSI.loss([]) == 0
    assert RSI.loss([4, 3, 2, 1]) == 3
    assert Float.round(RSI.loss(@prices3), 2) == 1.4
  end
end
