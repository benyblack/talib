defmodule TAlib.Indicators.BOPTest do
  use ExUnit.Case, async: true

  doctest TAlib.Indicators.BOP

  alias TAlib.Indicators.BOP

  test "bop/1 and bop_list/1" do
    bars = [
      %{open: 9.5, high: 10, low: 9, close: 9.5},
      %{open: 10.0, high: 11, low: 9.5, close: 10.5}
    ]

    assert BOP.bop(bars) |> Float.round(4) == 0.3333
    assert BOP.bop_list(bars) == [0.0, 0.3333333333333333]
    # Zero-range bars have an undefined balance of power.
    assert BOP.bop_list([%{open: 5, high: 5, low: 5, close: 5}]) == [nil]
    assert BOP.bop([]) == nil
  end
end
