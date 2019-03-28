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

  test "calculate MA" do
    assert MA.sma(@prices, 50) == 0
    assert MA.sma(@prices) == 0 #default period is 50
    assert Float.round(MA.sma(@prices, 10), 4) == 45.2752

  end

  test "calculate CMA" do
    assert MA.cma(@prices, 50) == 0
    assert MA.cma(@prices) == 0 #default period is 50
    assert Float.round(MA.cma(@prices, 10), 4) == 45.5422

  end

  test "calculate WMA" do
    assert MA.wma(@prices, 50) == 0
    assert MA.wma(@prices) == 0 #default period is 50
    assert Float.round(MA.wma([0,1,2,3], 3), 4) == 2.3333
    assert Float.round(MA.wma(@prices, 10), 4) == 45.8098
  end
end
