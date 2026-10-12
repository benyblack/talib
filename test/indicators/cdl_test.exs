defmodule TAlib.Indicators.CDLTest do
  use ExUnit.Case, async: true

  doctest TAlib.Indicators.CDL

  alias TAlib.Indicators.CDL

  # A deterministic mixed fixture (gaps, dojis, long shadows, marubozu
  # bars); every count below is cross-checked against the independent
  # reference implementation of the same definitions.
  @bars [
    %{open: 100.0, high: 101.0, low: 97.8, close: 96.8},
    %{open: 102.4327, high: 104.1327, low: 99.6327, close: 100.0327},
    %{open: 103.9563, high: 106.3563, low: 100.4563, close: 102.3563},
    %{open: 104.0896, high: 107.1896, low: 102.4896, close: 104.0896},
    %{open: 103.005, high: 106.805, low: 100.805, close: 103.005},
    %{open: 98.9477, high: 102.4477, low: 96.1477, close: 99.7477},
    %{open: 100.3853, high: 102.0853, low: 99.3853, close: 101.9853},
    %{open: 99.0526, high: 101.4526, low: 97.4526, close: 101.4526},
    %{open: 98.6062, high: 101.7062, low: 96.4062, close: 101.8062},
    %{open: 101.0504, high: 103.0504, low: 101.0504, close: 103.0504},
    %{open: 103.471, high: 104.471, low: 102.471, close: 101.071},
    %{open: 104.9645, high: 106.6645, low: 103.3645, close: 103.3645},
    %{open: 105.0638, high: 107.4638, low: 102.8638, close: 104.2638},
    %{open: 103.9573, high: 107.4573, low: 101.1573, close: 103.9573},
    %{open: 98.9006, high: 102.7006, low: 97.9006, close: 99.7006},
    %{open: 95.3609, high: 96.3609, low: 93.7609, close: 95.3609},
    %{open: 98.0625, high: 99.7625, low: 94.5625, close: 100.4625},
    %{open: 99.6456, high: 102.0456, low: 96.8456, close: 102.8456},
    %{open: 102.1009, high: 105.2009, low: 101.1009, close: 98.9009},
    %{open: 104.5087, high: 108.3087, low: 102.9087, close: 102.1087},
    %{open: 107.9718, high: 108.9718, low: 105.7718, close: 106.3718},
    %{open: 102.5372, high: 104.5372, low: 102.5372, close: 104.5372},
    %{open: 101.4094, high: 103.8094, low: 100.4094, close: 101.4094},
    %{open: 99.8538, high: 102.9538, low: 96.3538, close: 100.6538},
    %{open: 98.8373, high: 102.6373, low: 96.6373, close: 100.4373},
    %{open: 96.5731, high: 97.5731, low: 93.7731, close: 98.9731},
    %{open: 100.6855, high: 102.3855, low: 99.6855, close: 103.8855},
    %{open: 103.1513, high: 105.5513, low: 101.5513, close: 103.1513},
    %{open: 102.0459, high: 105.1459, low: 99.8459, close: 99.6459},
    %{open: 103.4783, high: 107.2783, low: 100.6783, close: 101.8783},
    %{open: 103.51, high: 104.51, low: 100.01, close: 102.71},
    %{open: 102.3612, high: 104.0612, low: 100.7612, close: 102.3612},
    %{open: 100.8073, high: 103.2073, low: 98.6073, close: 101.6073},
    %{open: 101.8144, high: 103.8144, low: 101.8144, close: 103.8144},
    %{open: 100.0846, high: 103.8846, low: 99.0846, close: 102.4846},
    %{open: 95.7259, high: 96.7259, low: 94.1259, close: 98.9259},
    %{open: 100.7016, high: 102.4016, low: 98.5016, close: 97.5016},
    %{open: 103.0825, high: 106.5825, low: 99.5825, close: 100.6825},
    %{open: 104.4839, high: 107.5839, low: 103.4839, close: 102.8839},
    %{open: 104.482, high: 108.282, low: 102.882, close: 104.482},
    %{open: 103.3127, high: 104.3127, low: 101.1127, close: 103.3127},
    %{open: 101.7612, high: 103.4612, low: 98.9612, close: 102.5612},
    %{open: 97.2923, high: 99.6923, low: 96.2923, close: 98.8923},
    %{open: 97.5969, high: 100.6969, low: 95.9969, close: 99.9969},
    %{open: 99.2669, high: 103.0669, low: 95.7669, close: 102.4669},
    %{open: 99.2519, high: 101.2519, low: 99.2519, close: 101.2519},
    %{open: 106.1185, high: 107.8185, low: 105.1185, close: 103.7185},
    %{open: 105.4887, high: 107.8887, low: 103.8887, close: 103.8887},
    %{open: 105.4533, high: 108.5533, low: 103.2533, close: 104.6533},
    %{open: 100.764, high: 104.564, low: 97.964, close: 100.764},
    %{open: 99.2155, high: 100.2155, low: 98.2155, close: 100.0155},
    %{open: 98.271, high: 99.971, low: 94.771, close: 98.271},
    %{open: 98.61, high: 101.01, low: 96.41, close: 101.01},
    %{open: 100.3083, high: 103.8083, low: 97.5083, close: 103.5083},
    %{open: 102.8022, high: 106.6022, low: 101.8022, close: 99.6022},
    %{open: 102.6539, high: 103.6539, low: 101.0539, close: 100.2539},
    %{open: 102.9927, high: 104.6927, low: 100.7927, close: 101.3927},
    %{open: 102.9239, high: 104.9239, low: 102.9239, close: 104.9239},
    %{open: 101.7152, high: 104.8152, low: 98.2152, close: 101.7152},
    %{open: 102.17, high: 105.97, low: 100.57, close: 102.97}
  ]

  test "score conventions on hand-made bars" do
    # Doji: open == close with a tiny body vs the average.
    assert CDL.doji([
             %{open: 10, high: 12, low: 8, close: 11},
             %{open: 10.5, high: 12, low: 9, close: 10.5},
             %{open: 11, high: 12, low: 10, close: 11.8}
           ]) == [0, 100, 0]

    # Hammer: lower shadow at least twice the body, small upper shadow.
    hammer = %{open: 10, high: 10.3, low: 8, close: 10.3}
    assert CDL.hammer([hammer]) == [100]
    assert CDL.hanging_man([hammer]) == [-100]

    # Marubozu: no shadows at all.
    assert CDL.marubozu([%{open: 10, high: 12, low: 10, close: 12}]) == [100]

    # Engulfing: second body strictly engulfs the first, opposite color.
    assert CDL.engulfing([
             %{open: 12.0, high: 12.5, low: 11.5, close: 11.8},
             %{open: 11.5, high: 13.0, low: 11.0, close: 12.9}
           ]) == [0, 100]

    # Bullish engulfing of a black candle.
    assert CDL.engulfing([
             %{open: 11, high: 11.2, low: 9.8, close: 10.0},
             %{open: 9.9, high: 12, low: 9.7, close: 11.9}
           ]) == [0, 100]
  end

  test "warmup bars of multi-bar patterns score zero" do
    bars = Enum.take(@bars, 2)
    assert CDL.two_crows(bars) == [0, 0]
  end

  test "average_period must be a positive integer" do
    assert_raise ArgumentError, ~r/positive integer/, fn -> CDL.doji(@bars, 0) end
  end

  test "matches the reference implementation on the mixed fixture" do
    assert counts(CDL.abandoned_baby(@bars)) == %{0 => 60}
    assert counts(CDL.advance_block(@bars)) == %{0 => 60}
    assert counts(CDL.belt_hold(@bars)) == %{0 => 57, 100 => 3}
    assert counts(CDL.breakaway(@bars)) == %{0 => 60}
    assert counts(CDL.closing_marubozu(@bars)) == %{-100 => 2, 0 => 51, 100 => 7}
    assert counts(CDL.conceal_babys_wall(@bars)) == %{0 => 60}
    assert counts(CDL.counterattack(@bars)) == %{0 => 60}
    assert counts(CDL.dark_cloud_cover(@bars)) == %{-100 => 1, 0 => 59}
    assert counts(CDL.doji(@bars)) == %{0 => 48, 100 => 12}
    assert counts(CDL.doji_star(@bars)) == %{0 => 60}
    assert counts(CDL.dragonfly_doji(@bars)) == %{0 => 60}
    assert counts(CDL.engulfing(@bars)) == %{0 => 60}
    assert counts(CDL.evening_doji_star(@bars)) == %{0 => 60}
    assert counts(CDL.evening_star(@bars)) == %{0 => 60}
    assert counts(CDL.gap_side_side_white(@bars)) == %{0 => 57, 100 => 3}
    assert counts(CDL.gravestone_doji(@bars)) == %{0 => 60}
    assert counts(CDL.hammer(@bars)) == %{0 => 60}
    assert counts(CDL.hanging_man(@bars)) == %{0 => 60}
    assert counts(CDL.harami(@bars)) == %{-100 => 1, 0 => 59}
    assert counts(CDL.harami_cross(@bars)) == %{-100 => 1, 0 => 59}
    assert counts(CDL.high_wave(@bars)) == %{0 => 50, 100 => 10}
    assert counts(CDL.hikkake(@bars)) == %{-100 => 1, 0 => 55, 100 => 4}
    assert counts(CDL.hikkake_mod(@bars)) == %{-100 => 1, 0 => 55, 100 => 4}
    assert counts(CDL.homing_pigeon(@bars)) == %{0 => 60}
    assert counts(CDL.identical_3_crows(@bars)) == %{0 => 60}
    assert counts(CDL.in_neck(@bars)) == %{0 => 60}
    assert counts(CDL.inverted_hammer(@bars)) == %{0 => 59, 100 => 1}
    assert counts(CDL.kicking(@bars)) == %{0 => 60}
    assert counts(CDL.kicking_by_length(@bars)) == %{0 => 60}
    assert counts(CDL.ladder_bottom(@bars)) == %{0 => 60}
    assert counts(CDL.long_legged_doji(@bars)) == %{0 => 49, 100 => 11}
    assert counts(CDL.long_line(@bars)) == %{-100 => 3, 0 => 41, 100 => 16}
    assert counts(CDL.marubozu(@bars)) == %{0 => 55, 100 => 5}
    assert counts(CDL.mat_hold(@bars)) == %{0 => 60}
    assert counts(CDL.matching_low(@bars)) == %{0 => 60}
    assert counts(CDL.morning_doji_star(@bars)) == %{0 => 60}
    assert counts(CDL.morning_star(@bars)) == %{0 => 60}
    assert counts(CDL.on_neck(@bars)) == %{0 => 60}
    assert counts(CDL.piercing(@bars)) == %{0 => 60}
    assert counts(CDL.rickshaw_man(@bars)) == %{0 => 49, 100 => 11}
    assert counts(CDL.rise_fall_3_methods(@bars)) == %{0 => 60}
    assert counts(CDL.separating_lines(@bars)) == %{-100 => 3, 0 => 56, 100 => 1}
    assert counts(CDL.shooting_star(@bars)) == %{-100 => 1, 0 => 59}
    assert counts(CDL.short_line(@bars)) == %{0 => 58, 100 => 2}
    assert counts(CDL.spinning_top(@bars)) == %{0 => 54, 100 => 6}
    assert counts(CDL.stalled_pattern(@bars)) == %{0 => 60}
    assert counts(CDL.stick_sandwich(@bars)) == %{0 => 60}
    assert counts(CDL.takuri(@bars)) == %{0 => 60}
    assert counts(CDL.tasuki_gap(@bars)) == %{0 => 60}
    assert counts(CDL.three_black_crows(@bars)) == %{0 => 60}
    assert counts(CDL.three_inside(@bars)) == %{-100 => 1, 0 => 59}
    assert counts(CDL.three_line_strike(@bars)) == %{0 => 60}
    assert counts(CDL.three_outside(@bars)) == %{0 => 60}
    assert counts(CDL.three_stars_in_south(@bars)) == %{0 => 60}
    assert counts(CDL.three_white_soldiers(@bars)) == %{0 => 59, 100 => 1}
    assert counts(CDL.thrusting(@bars)) == %{0 => 60}
    assert counts(CDL.tristar(@bars)) == %{0 => 60}
    assert counts(CDL.two_crows(@bars)) == %{0 => 60}
    assert counts(CDL.unique_3_river(@bars)) == %{0 => 60}
    assert counts(CDL.upside_gap_2crows(@bars)) == %{0 => 60}
    assert counts(CDL.xside_gap_3methods(@bars)) == %{0 => 60}
  end

  defp counts(scores), do: Enum.frequencies(scores)
end
