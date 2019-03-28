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
    46.282
  ]

  test "calculate RSI" do
    # there should be somthing like AssertAlmostEqual in Python
    assert Float.round(RSI.rsi(@prices), 2) == 70.53
    assert Float.round(RSI.rsi(@prices, 7), 2) == 70.67
    assert RSI.rsi(@prices, 28) == 0
  end

  test "average gain" do
    assert RSI.average_gain([10, 20, 30, 40]) == 7.5
    assert RSI.average_gain([3, 2, 1]) == 0
    assert RSI.average_gain([]) == 0
    assert Float.round(RSI.average_gain(@prices), 4) == 0.2384
    assert RSI.average_gain([1, 2, 3, 4], 2) == 0.5
  end

  test "average loss" do
    assert RSI.average_loss([30, 20, 10, 0]) == 7.5
    assert RSI.average_loss([1, 2, 3]) == 0
    assert RSI.average_loss([]) == 0
    assert Float.round(RSI.average_loss(@prices), 4) == 0.0996
    assert RSI.average_loss([4, 3, 2, 1], 2) == 0.5
  end
end
