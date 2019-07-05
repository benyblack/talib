defmodule TAlib.Tests.RsiTests do
  use ExUnit.Case
  alias TAlib.Indicators.RSI

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
    46.282,
    46.28
  ]

  @prices3 [
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
  ]

  @prices2 [
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
  ]

  test "calculate RSI list" do
    data =  for i <- 1..100, do: i
    expected = [nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil] ++ List.duplicate(100, 86)
    assert RSI.rsi_list(data, 14) == expected
    expected2 = List.duplicate(0.0, 86) ++ [nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil]
    assert RSI.rsi_list(data, 14, true) == expected2
  end

  test "calculate RSI" do
    # Compared with https://www.marketvolume.com/quotes/calculatersi.asp
    assert Float.round(RSI.rsi(@prices3), 2) == 70.46
    assert Float.round(RSI.rsi(@prices2), 2) == 75.89
  end

  test "average loss" do
    assert RSI.average_loss([10, 20, 30, 40], 3) == 10
    assert RSI.average_loss([3, 2, 1]) == 0
    assert RSI.average_loss([]) == 0
    assert Float.round(RSI.average_loss(@prices), 4) == 0.1921
    assert RSI.average_loss([1, 2, 3, 4], 2) == 1
  end

  test "average gain" do
    assert RSI.average_gain([30, 20, 10, 0], 3) == 10
    assert RSI.average_gain([]) == 0
    assert Float.round(RSI.average_gain(@prices), 2) == 0.10
    assert RSI.average_gain([4, 3, 2, 1], 2) == 1
  end

  test "total gain" do
    assert RSI.gain([30, 20, 10, 0]) == 30
    assert RSI.gain([]) == 0
    assert RSI.gain([4, 3, 2, 1]) == 3
    assert Float.round(RSI.gain(@prices3), 2) == 3.34
  end

  test "total loss" do
    assert RSI.loss([10, 20, 30, 40]) == 30
    assert RSI.loss([3, 2, 1]) == 0
    assert RSI.loss([]) == 0
    assert RSI.loss([1, 2, 3, 4]) == 3
    assert Float.round(RSI.loss(@prices3), 2) == 1.4
  end
end
