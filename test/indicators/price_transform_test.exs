defmodule TAlib.Indicators.PriceTransformTest do
  use ExUnit.Case, async: true

  doctest TAlib.Indicators.PriceTransform

  alias TAlib.Indicators.PriceTransform

  test "per-bar transforms" do
    bar = %{open: 10, high: 12, low: 8, close: 11}

    assert PriceTransform.avgprice(bar) == 10.25
    assert PriceTransform.medprice(bar) == 10.0
    assert Float.round(PriceTransform.typprice(bar), 4) == 10.3333
    assert PriceTransform.wclprice(bar) == 10.5

    bars = [%{bar | close: 10}, %{bar | close: 12}]
    assert PriceTransform.typprice_list(bars) == [10.0, 10.666666666666666]
  end
end
