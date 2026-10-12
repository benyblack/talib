defmodule TAlib.Indicators.CDL do
  @moduledoc """
  Candlestick pattern recognition (TA-Lib Pattern Recognition group).

  Every function takes bars — maps with at least `:open`, `:high`, `:low`
  and `:close`, oldest first — and returns a score per bar, aligned with
  the input: `100` bullish, `-100` bearish, `0` no pattern (also for the
  warmup bars of multi-bar patterns). `hikkake`/`hikkake_mod` follow the
  base-setup convention here (`±100`); TA-Lib's confirmed `±200` levels
  are pending.

  Thresholds follow the TA-Lib/StockCharts conventions: a body is *long*
  when it reaches the average body, *short* at two thirds of it, very
  long at 4/3 and a doji at 3%; `average_period` (default 5) is the
  window of that trailing average body. The `penetration` parameters are
  fractions of the reference body, defaulting to 0.5 like TA-Lib. See
  `TAlib` for the remaining conventions.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  # Per-bar candle context: body/shadow sizes plus the trailing average
  # body (partial while warming up, as in TA-Lib).
  defp context(bars, average_period) do
    bodies = Enum.map(bars, fn bar -> abs(bar.close - bar.open) end)

    bars
    |> Enum.with_index()
    |> Enum.map(fn {bar, index} ->
      count = min(index + 1, average_period)
      avg = Enum.sum(Enum.slice(bodies, index - count + 1, count)) / count

      %{
        o: bar.open,
        h: bar.high,
        l: bar.low,
        c: bar.close,
        body: abs(bar.close - bar.open),
        up: bar.high - max(bar.open, bar.close),
        lo: min(bar.open, bar.close) - bar.low,
        avg: avg
      }
    end)
  end

  defp score_list(bars, average_period, window, fun) when is_valid_period(average_period) do
    ctx = context(bars, average_period)

    ctx
    |> Enum.with_index()
    |> Enum.map(fn {_bar, index} ->
      if index < window - 1, do: 0, else: fun.(Enum.slice(ctx, index - window + 1, window))
    end)
  end

  defp score_list(_bars, average_period, _window, _fun), do: TAlib.invalid_period!(average_period)

  defp white(b), do: b.c > b.o
  defp black(b), do: b.c < b.o
  defp long(b), do: b.body >= b.avg
  defp small(b), do: b.body <= b.avg * 0.667
  defp doji_b(b), do: b.body <= b.avg * 0.03
  defp maxb(b), do: max(b.o, b.c)
  defp minb(b), do: min(b.o, b.c)
  defp near(a, b, tol), do: abs(a - b) <= tol
  defp gap_up(b, prev), do: minb(b) > maxb(prev)
  defp gap_down(b, prev), do: maxb(b) < minb(prev)
  defp body_inside(b, prev), do: maxb(b) < maxb(prev) and minb(b) > minb(prev)
  defp inside(b, prev), do: b.h < prev.h and b.l > prev.l
  defp tol(b), do: b.avg * 0.05

  @doc "Two Crows (bearish, 3 bars)."
  def two_crows(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 3, fn [a, b, c] ->
        if white(a) and long(a) and black(b) and gap_up(b, a) and black(c) and
             c.o >= minb(b) and c.o <= maxb(b) and c.c < b.c and c.c > a.c,
           do: -100,
           else: 0
      end)

  @doc "Three Black Crows (bearish, 3 bars)."
  def three_black_crows(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 3, fn [a, b, c] ->
        if black(a) and black(b) and black(c) and
             (a.body + b.body + c.body) / 3 >= c.avg and
             b.c < a.c and c.c < b.c and
             b.o <= a.o and b.o > a.c and c.o <= b.o and c.o > b.c,
           do: -100,
           else: 0
      end)

  @doc "Three Inside Up/Down (2 bars)."
  def three_inside(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 2, fn [a, b] ->
        if long(a) and body_inside(b, a) and white(a) != white(b),
          do: if(white(b), do: 100, else: -100),
          else: 0
      end)

  @doc "Three-Line Strike (4 bars)."
  def three_line_strike(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 4, fn [a, b, c, d] ->
        bull =
          white(a) and white(b) and white(c) and
            b.o >= a.o and b.o <= a.c and c.o >= b.o and c.o <= b.c and
            b.c > a.c and c.c > b.c and black(d) and d.o > c.c and d.c < a.o

        bear =
          black(a) and black(b) and black(c) and
            b.o <= a.o and b.o >= a.c and c.o <= b.o and c.o >= b.c and
            b.c < a.c and c.c < b.c and white(d) and d.o < c.c and d.c > a.o

        cond do
          bull -> -100
          bear -> 100
          true -> 0
        end
      end)

  @doc "Three Outside Up/Down (2 bars)."
  def three_outside(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 2, fn [a, b] ->
        if b.h > a.h and b.l < a.l and white(a) != white(b),
          do: if(white(b), do: 100, else: -100),
          else: 0
      end)

  @doc "Three Stars in the South (bullish, 3 bars)."
  def three_stars_in_south(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 3, fn [a, b, c] ->
        if black(a) and long(a) and a.lo >= a.avg and a.up <= a.body and
             black(b) and small(b) and b.l > a.l and b.h < a.h and
             small(c) and c.l > b.l and c.c > b.c and c.c <= maxb(b) and c.c >= minb(b),
           do: 100,
           else: 0
      end)

  @doc "Three Advancing White Soldiers (bullish, 3 bars)."
  def three_white_soldiers(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 3, fn [a, b, c] ->
        if white(a) and white(b) and white(c) and
             (a.body + b.body + c.body) / 3 >= c.avg and
             b.o >= a.o and b.o <= a.c and c.o >= b.o and c.o <= b.c and
             b.c > a.c and c.c > b.c,
           do: 100,
           else: 0
      end)

  @doc "Abandoned Baby (reversal, 3 bars, full gaps around a doji)."
  def abandoned_baby(bars, penetration \\ 0.3, average_period \\ 5),
    do:
      score_list(bars, average_period, 3, fn [a, b, c] ->
        bull =
          black(a) and doji_b(b) and b.h < a.l - a.avg * penetration * 0 and c.l > b.h and
            white(c)

        bear = white(a) and doji_b(b) and b.l > a.h and c.h < b.l and black(c)

        cond do
          bull -> 100
          bear -> -100
          true -> 0
        end
      end)

  @doc "Advance Block (bearish, 3 bars)."
  def advance_block(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 3, fn [a, b, c] ->
        if white(a) and white(b) and white(c) and
             b.o >= a.o and b.o <= a.c and c.o >= b.o and c.o <= b.c and
             b.c > a.c and c.c > b.c and
             b.up >= b.avg * 0.3 and c.up >= c.avg * 0.3 and c.body < b.body,
           do: -100,
           else: 0
      end)

  @doc "Belt Hold (single bar opening at the extreme)."
  def belt_hold(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 1, fn [a] ->
        cond do
          white(a) and long(a) and a.lo == 0 -> 100
          black(a) and long(a) and a.up == 0 -> -100
          true -> 0
        end
      end)

  @doc "Breakaway (bullish reversal, 5 bars)."
  def breakaway(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 5, fn [a, b, c, d, e] ->
        if black(a) and long(a) and b.h < a.l and d.l < b.l and
             white(e) and long(e) and e.c > max(b.h, max(c.h, d.h)) and e.c < a.c,
           do: 100,
           else: 0
      end)

  @doc "Closing Marubozu (no shadow on the closing end)."
  def closing_marubozu(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 1, fn [a] ->
        cond do
          white(a) and a.up == 0 -> 100
          black(a) and a.lo == 0 -> -100
          true -> 0
        end
      end)

  @doc "Concealing Baby Swallow (bearish, 4 bars)."
  def conceal_babys_wall(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 4, fn [a, b, c, d] ->
        if black(a) and long(a) and a.lo >= a.avg and
             black(b) and b.body <= b.avg * 0.33 and maxb(b) < a.l and
             black(c) and c.h < b.l and c.body <= c.avg * 0.33 and
             black(d) and d.o >= minb(c) and d.o <= maxb(c) and d.c < c.l,
           do: -100,
           else: 0
      end)

  @doc "Counterattack (2 bars, closes at the prior open)."
  def counterattack(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 2, fn [a, b] ->
        t = tol(b)

        cond do
          black(a) and white(b) and near(b.o, a.c, t) and b.c >= a.o -> 100
          white(a) and black(b) and near(b.o, a.c, t) and b.c <= a.o -> -100
          true -> 0
        end
      end)

  @doc "Dark Cloud Cover (bearish, 2 bars)."
  def dark_cloud_cover(bars, penetration \\ 0.5, average_period \\ 5),
    do:
      score_list(bars, average_period, 2, fn [a, b] ->
        if white(a) and long(a) and black(b) and b.o >= a.c and
             b.c < a.o + a.body * (1 - penetration) and b.c > a.o,
           do: -100,
           else: 0
      end)

  @doc "Doji (body at 3% of the average)."
  def doji(bars, average_period \\ 5),
    do: score_list(bars, average_period, 1, fn [a] -> if doji_b(a), do: 100, else: 0 end)

  @doc "Doji Star (2 bars)."
  def doji_star(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 2, fn [a, b] ->
        cond do
          long(a) and doji_b(b) and black(a) and gap_down(b, a) -> 100
          long(a) and doji_b(b) and white(a) and gap_up(b, a) -> -100
          true -> 0
        end
      end)

  @doc "Dragonfly Doji (no upper shadow)."
  def dragonfly_doji(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 1, fn [a] ->
        if doji_b(a) and a.up <= a.avg * 0.03, do: 100, else: 0
      end)

  @doc "Engulfing Pattern (2 bars)."
  def engulfing(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 2, fn [a, b] ->
        engulfs =
          b.body > a.body and maxb(b) >= maxb(a) and minb(b) <= minb(a) and
            (maxb(b) > maxb(a) or minb(b) < minb(a))

        if engulfs and white(a) != white(b), do: if(white(b), do: 100, else: -100), else: 0
      end)

  @doc "Evening Doji Star (bearish, 3 bars)."
  def evening_doji_star(bars, penetration \\ 0.3, average_period \\ 5),
    do:
      score_list(bars, average_period, 3, fn [a, b, c] ->
        if white(a) and long(a) and doji_b(b) and gap_up(b, a) and black(c) and
             c.c < a.o + a.body * (1 - penetration),
           do: -100,
           else: 0
      end)

  @doc "Evening Star (bearish, 3 bars)."
  def evening_star(bars, penetration \\ 0.3, average_period \\ 5),
    do:
      score_list(bars, average_period, 3, fn [a, b, c] ->
        if white(a) and long(a) and small(b) and gap_up(b, a) and black(c) and
             c.c < a.o + a.body * (1 - penetration),
           do: -100,
           else: 0
      end)

  @doc "Up/Downside Gap Side-by-Side White Lines (2 bars)."
  def gap_side_side_white(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 2, fn [a, b] ->
        if white(a) and white(b) and gap_up(b, a) and b.body >= a.body * 0.667, do: 100, else: 0
      end)

  @doc "Gravestone Doji (no lower shadow)."
  def gravestone_doji(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 1, fn [a] ->
        if doji_b(a) and a.lo <= a.avg * 0.03, do: 100, else: 0
      end)

  @doc "Hammer (lower shadow at least twice the body)."
  def hammer(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 1, fn [a] ->
        if a.body > 0 and a.lo >= 2 * a.body and a.up <= a.body, do: 100, else: 0
      end)

  @doc "Hanging Man (hammer shape after a downtrend)."
  def hanging_man(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 1, fn [a] ->
        if a.body > 0 and a.lo >= 2 * a.body and a.up <= a.body, do: -100, else: 0
      end)

  @doc "Harami Pattern (2 bars)."
  def harami(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 2, fn [a, b] ->
        if long(a) and body_inside(b, a) and white(a) != white(b),
          do: if(white(b), do: 100, else: -100),
          else: 0
      end)

  @doc "Harami Cross Pattern (2 bars, inside doji)."
  def harami_cross(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 2, fn [a, b] ->
        if long(a) and doji_b(b) and maxb(b) < maxb(a) and minb(b) > minb(a),
          do: if(black(a), do: 100, else: -100),
          else: 0
      end)

  @doc "High-Wave Candle (small body, very long shadows)."
  def high_wave(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 1, fn [a] ->
        if small(a) and a.up >= a.avg and a.lo >= a.avg, do: 100, else: 0
      end)

  @doc "Hikkake (base setup, 3 bars)."
  def hikkake(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 3, fn [a, b, c] ->
        cond do
          inside(b, a) and c.h > b.h and c.l > b.l -> -100
          inside(b, a) and c.h < b.h and c.l < b.l -> 100
          true -> 0
        end
      end)

  @doc "Hikkake Modifier (base setup here; ±200 confirmation pending)."
  def hikkake_mod(bars, average_period \\ 5), do: hikkake(bars, average_period)

  @doc "Homing Pigeon (bullish, 2 bars)."
  def homing_pigeon(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 2, fn [a, b] ->
        if black(a) and long(a) and black(b) and small(b) and body_inside(b, a), do: 100, else: 0
      end)

  @doc "Identical Three Crows (bearish, 3 bars)."
  def identical_3_crows(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 3, fn [a, b, c] ->
        if black(a) and black(b) and black(c) and
             near(b.o, a.c, a.avg * 0.1) and near(c.o, b.c, b.avg * 0.1) and
             b.c < a.c and c.c < b.c,
           do: -100,
           else: 0
      end)

  @doc "In-Neck Pattern (bearish continuation, 2 bars)."
  def in_neck(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 2, fn [a, b] ->
        if black(a) and long(a) and white(b) and b.o < a.l and
             b.c <= a.c and b.c > a.c - a.avg * 0.05,
           do: -100,
           else: 0
      end)

  @doc "Inverted Hammer (upper shadow at least twice the body)."
  def inverted_hammer(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 1, fn [a] ->
        if a.body > 0 and a.up >= 2 * a.body and a.lo <= a.body, do: 100, else: 0
      end)

  @doc "Kicking (2 marubozu-gap bars)."
  def kicking(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 2, fn [a, b] ->
        maru = fn x -> x.up <= x.body * 0.1 and x.lo <= x.body * 0.1 end

        cond do
          maru.(a) and maru.(b) and black(a) and white(b) and minb(b) > maxb(a) -> 100
          maru.(a) and maru.(b) and white(a) and black(b) and maxb(b) < minb(a) -> -100
          true -> 0
        end
      end)

  @doc "Kicking determined by length (the new-direction marubozu is longer)."
  def kicking_by_length(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 2, fn [a, b] ->
        maru = fn x -> x.up <= x.body * 0.1 and x.lo <= x.body * 0.1 end

        cond do
          maru.(a) and maru.(b) and black(a) and white(b) and b.body > a.body and
              minb(b) > maxb(a) ->
            100

          maru.(a) and maru.(b) and white(a) and black(b) and b.body > a.body and
              maxb(b) < minb(a) ->
            -100

          true ->
            0
        end
      end)

  @doc "Ladder Bottom (bullish reversal, 5 bars)."
  def ladder_bottom(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 5, fn [a, b, c, d, e] ->
        if black(a) and black(b) and black(c) and b.o < a.l and c.o < b.l and
             black(d) and small(d) and d.o > c.c and
             white(e) and e.c > d.h,
           do: 100,
           else: 0
      end)

  @doc "Long Legged Doji (doji with long shadows on both sides)."
  def long_legged_doji(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 1, fn [a] ->
        if doji_b(a) and a.up >= a.avg * 0.667 and a.lo >= a.avg * 0.667, do: 100, else: 0
      end)

  @doc "Long Line Candle (body at 4/3 of the average)."
  def long_line(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 1, fn [a] ->
        if a.body >= a.avg * 1.33, do: if(white(a), do: 100, else: -100), else: 0
      end)

  @doc "Marubozu (no shadows on either end)."
  def marubozu(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 1, fn [a] ->
        if a.up == 0 and a.lo == 0 and a.body > 0, do: if(white(a), do: 100, else: -100), else: 0
      end)

  @doc "Matching Low (bullish, 2 bars closing at the same level)."
  def matching_low(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 2, fn [a, b] ->
        if black(a) and long(a) and black(b) and near(b.c, a.c, tol(b)), do: 100, else: 0
      end)

  @doc "Mat Hold (bullish continuation, 5 bars)."
  def mat_hold(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 5, fn [a, b, c, d, e] ->
        if white(a) and long(a) and gap_up(b, a) and b.body <= b.avg * 0.667 and
             c.body <= c.avg * 0.667 and d.body <= d.avg * 0.667 and
             c.l > a.c and d.l > a.c and white(e) and e.c > b.h,
           do: 100,
           else: 0
      end)

  @doc "Morning Doji Star (bullish, 3 bars)."
  def morning_doji_star(bars, penetration \\ 0.3, average_period \\ 5),
    do:
      score_list(bars, average_period, 3, fn [a, b, c] ->
        if black(a) and long(a) and doji_b(b) and gap_down(b, a) and white(c) and
             c.c > a.c + a.body * penetration,
           do: 100,
           else: 0
      end)

  @doc "Morning Star (bullish, 3 bars)."
  def morning_star(bars, penetration \\ 0.3, average_period \\ 5),
    do:
      score_list(bars, average_period, 3, fn [a, b, c] ->
        if black(a) and long(a) and small(b) and gap_down(b, a) and white(c) and
             c.c > a.c + a.body * penetration,
           do: 100,
           else: 0
      end)

  @doc "On-Neck Pattern (bearish, 2 bars closing at the prior low)."
  def on_neck(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 2, fn [a, b] ->
        if black(a) and long(a) and white(b) and b.o < a.c and near(b.c, a.l, tol(b)),
          do: -100,
          else: 0
      end)

  @doc "Piercing Pattern (bullish, 2 bars)."
  def piercing(bars, penetration \\ 0.5, average_period \\ 5),
    do:
      score_list(bars, average_period, 2, fn [a, b] ->
        if black(a) and long(a) and white(b) and b.o < a.l and
             b.c > a.c + a.body * penetration and b.c < a.o,
           do: 100,
           else: 0
      end)

  @doc "Rickshaw Man (doji with a long range centered on the body)."
  def rickshaw_man(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 1, fn [a] ->
        if doji_b(a) and a.up >= a.avg * 0.667 and a.lo >= a.avg * 0.667, do: 100, else: 0
      end)

  @doc "Rising/Falling Three Methods (continuation, 5 bars)."
  def rise_fall_3_methods(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 5, fn [a, b, c, d, e] ->
        contained = fn x -> maxb(x) <= maxb(a) and minb(x) >= minb(a) end

        bull =
          white(a) and long(a) and black(b) and black(c) and black(d) and
            small(b) and small(c) and small(d) and contained.(b) and contained.(c) and
            contained.(d) and white(e) and e.c > a.c

        bear =
          black(a) and long(a) and white(b) and white(c) and white(d) and
            small(b) and small(c) and small(d) and contained.(b) and contained.(c) and
            contained.(d) and black(e) and e.c < a.c

        cond do
          bull -> 100
          bear -> -100
          true -> 0
        end
      end)

  @doc "Separating Lines (2 bars opening at the same level)."
  def separating_lines(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 2, fn [a, b] ->
        if white(a) == white(b) and not doji_b(a) and not doji_b(b) and near(b.o, a.o, tol(b)),
          do: if(white(b), do: 100, else: -100),
          else: 0
      end)

  @doc "Shooting Star (inverted-hammer shape, bearish)."
  def shooting_star(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 1, fn [a] ->
        if a.body > 0 and a.up >= 2 * a.body and a.lo <= a.body, do: -100, else: 0
      end)

  @doc "Short Line Candle (small body, short shadows)."
  def short_line(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 1, fn [a] ->
        if small(a) and a.up <= a.avg * 0.667 and a.lo <= a.avg * 0.667, do: 100, else: 0
      end)

  @doc "Spinning Top (small body, shadows larger than the body)."
  def spinning_top(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 1, fn [a] ->
        if a.body > 0 and small(a) and a.up > a.body and a.lo > a.body, do: 100, else: 0
      end)

  @doc "Stalled Pattern (bearish, 3 bars)."
  def stalled_pattern(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 3, fn [a, b, c] ->
        if white(a) and white(b) and b.c > a.c and long(b) and
             white(c) and small(c) and c.up >= c.avg and c.c > b.c,
           do: -100,
           else: 0
      end)

  @doc "Stick Sandwich (bullish, 3 bars with matching outer closes)."
  def stick_sandwich(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 3, fn [a, b, c] ->
        if black(a) and white(b) and b.c > a.c and black(c) and near(c.c, a.c, tol(c)),
          do: 100,
          else: 0
      end)

  @doc "Takuri (dragonfly doji with a very long lower shadow)."
  def takuri(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 1, fn [a] ->
        if a.body > 0 and a.lo >= 3 * a.body and a.up <= a.body * 0.25, do: 100, else: 0
      end)

  @doc "Tasuki Gap (continuation, 3 bars)."
  def tasuki_gap(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 3, fn [a, b, c] ->
        bull =
          white(a) and white(b) and gap_up(b, a) and black(c) and
            c.o > minb(b) and c.o < maxb(b) and c.c < b.o

        bear =
          black(a) and black(b) and gap_down(b, a) and white(c) and
            c.o > minb(b) and c.o < maxb(b) and c.c > b.o

        cond do
          bull -> 100
          bear -> -100
          true -> 0
        end
      end)

  @doc "Thrusting Pattern (bearish, 2 bars)."
  def thrusting(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 2, fn [a, b] ->
        if black(a) and long(a) and white(b) and b.o < a.l and
             b.c > a.c and b.c < (a.o + a.c) / 2,
           do: -100,
           else: 0
      end)

  @doc "Tristar Pattern (three dojis)."
  def tristar(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 3, fn [a, b, c] ->
        cond do
          doji_b(a) and doji_b(b) and doji_b(c) and gap_up(b, a) and gap_down(c, b) -> -100
          doji_b(a) and doji_b(b) and doji_b(c) and gap_down(b, a) and gap_up(c, b) -> 100
          true -> 0
        end
      end)

  @doc "Unique Three River (bullish, 3 bars)."
  def unique_3_river(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 3, fn [a, b, c] ->
        if black(a) and long(a) and black(b) and maxb(b) < maxb(a) and b.l < a.l and
             b.lo >= 2 * b.body and white(c) and small(c) and c.c > b.c and c.c < maxb(b),
           do: 100,
           else: 0
      end)

  @doc "Upside Gap Two Crows (bearish, 3 bars)."
  def upside_gap_2crows(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 3, fn [a, b, c] ->
        if white(a) and long(a) and black(b) and gap_up(b, a) and black(c) and
             minb(c) > maxb(a) and c.o > b.o and c.c < b.c,
           do: -100,
           else: 0
      end)

  @doc "Upside/Downside Gap Three Methods (3 bars filling the gap)."
  def xside_gap_3methods(bars, average_period \\ 5),
    do:
      score_list(bars, average_period, 3, fn [a, b, c] ->
        bear =
          white(a) and white(b) and gap_up(b, a) and black(c) and c.c < minb(b) and c.c > maxb(a)

        bull =
          black(a) and black(b) and gap_down(b, a) and white(c) and c.c > maxb(b) and
            c.c < minb(a)

        cond do
          bear -> -100
          bull -> 100
          true -> 0
        end
      end)
end
