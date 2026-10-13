defmodule TAlib.Indicators.CDL do
  @moduledoc """
  Candlestick pattern recognition (TA-Lib Pattern Recognition group),
  translated bar for bar from TA-Lib's C definitions.

  Every function takes bars — maps with at least `:open`, `:high`,
  `:low` and `:close`, oldest first — and returns one score per bar,
  aligned with the input: `100` bullish, `-100` bearish, `0` no
  pattern. Bars inside the pattern's lookback score `0`. The hikkake
  functions follow TA-Lib's confirmation convention: the bar that
  confirms a recent setup scores `±200` (the setup's direction), and
  `engulfing`/`harami`/`harami_cross` score `±80` when the touching
  bodies are merely equal rather than strictly engulfing.

  Thresholds are TA-Lib's global candle settings, applied exactly as
  the C library applies them (each average covers the bars *before*
  the candle being judged):

    - bodies are long/short against the average real body of the
      10 previous candles (factor 1.0), very long at 3x;
    - a doji body is under 10% of the average high-low range of the
      10 previous candles;
    - a shadow is long beyond the candle's own real body, very long
      beyond 2x, short under half the average shadow sum of the 10
      previous candles, very short under 10% of the average high-low
      range;
    - "near"/"far"/"equal" distances are 20%/60%/5% of the average
      high-low range of the 5 previous candles.

  The `penetration` parameters are fractions of the reference body,
  defaulting like TA-Lib (0.3 for the star patterns, 0.5 for the
  rest). See `TAlib` for the remaining conventions.
  """

  # ------------------------------------------------------------------
  # Per-bar candle context: raw sizes plus the four trailing sums the
  # candle settings need — real bodies (10), high-low ranges (10),
  # shadow sums (10) and high-low ranges (5) — each over the bars
  # *before* the current one, sliding like the C code (the entering
  # range added, the leaving one subtracted).
  # ------------------------------------------------------------------

  defp context(bars) do
    ctx =
      Enum.map(bars, fn bar ->
        %{
          o: bar.open,
          h: bar.high,
          l: bar.low,
          c: bar.close,
          body: abs(bar.close - bar.open),
          up: bar.high - max(bar.open, bar.close),
          lo: min(bar.open, bar.close) - bar.low
        }
      end)

    body10 = sliding_sums(ctx, 10, :body)
    hl10 = sliding_sums(ctx, 10, :hl)
    shadow10 = sliding_sums(ctx, 10, :shadow)
    hl5 = sliding_sums(ctx, 5, :hl)

    [ctx, body10, hl10, shadow10, hl5]
    |> Enum.zip()
    |> Enum.map(fn {bar, b10, h10, sh10, h5} ->
      bar
      |> Map.put(:body10, b10)
      |> Map.put(:hl10, h10)
      |> Map.put(:shadow10, sh10)
      |> Map.put(:hl5, h5)
    end)
  end

  defp hl(%{h: h, l: l}), do: h - l
  defp shadow(%{up: up, lo: lo}), do: up + lo

  # sums[k] = the `key` range summed over the n bars before k: each
  # step records the current sum first, then slides the window by
  # adding the entering range and subtracting the leaving one.
  defp sliding_sums(ctx, n, key) do
    value = value_fun(key)

    {reversed, _} =
      Enum.reduce(ctx, {[], {0.0, []}}, fn bar, {acc, {sum, past}} ->
        v = value.(bar)

        {next_sum, next_past} =
          if length(past) == n do
            {sum + (v - hd(past)), tl(past) ++ [v]}
          else
            {sum + v, past ++ [v]}
          end

        {[sum | acc], {next_sum, next_past}}
      end)

    Enum.reverse(reversed)
  end

  defp value_fun(:body), do: fn bar -> bar.body end
  defp value_fun(:hl), do: &hl/1
  defp value_fun(:shadow), do: &shadow/1

  # ------------------------------------------------------------------
  # Candle settings, each the TA_CANDLEAVERAGE of its row in TA-Lib's
  # default table: factor * (sum / avgPeriod), halved for the shadow
  # sum (Shadows range type), the candle's own body when avgPeriod 0.
  # ------------------------------------------------------------------

  defp white(b), do: b.c >= b.o
  defp black(b), do: b.c < b.o

  defp maxb(b), do: max(b.o, b.c)
  defp minb(b), do: min(b.o, b.c)

  defp body_long(b), do: b.body > b.body10 / 10
  defp body_short(b), do: b.body < b.body10 / 10
  defp doji_body(b), do: b.body <= 0.1 * (b.hl10 / 10)
  defp shadow_long(b), do: 1.0 * b.body
  defp shadow_very_long(b), do: 2.0 * b.body
  defp shadow_short(b), do: b.shadow10 / 10 / 2.0
  defp shadow_very_short(b), do: 0.1 * (b.hl10 / 10)
  defp near(b), do: 0.2 * (b.hl5 / 5)
  defp far(b), do: 0.6 * (b.hl5 / 5)
  defp equal_tol(b), do: 0.05 * (b.hl5 / 5)

  defp gap_up(b, prev), do: minb(b) > maxb(prev)
  defp gap_down(b, prev), do: maxb(b) < minb(prev)

  # ------------------------------------------------------------------
  # Scoring: windows of `window` context bars, evaluated only from the
  # pattern's lookback bar on (the C library outputs nothing before
  # it), zero-padded before that.
  # ------------------------------------------------------------------

  defp score(bars, lookback, window, fun) do
    ctx = context(bars)

    windows =
      ctx
      |> Enum.chunk_every(window, 1, :discard)
      |> Enum.drop(max(lookback - window + 1, 0))

    List.duplicate(0, min(lookback, length(bars))) ++ Enum.map(windows, fun)
  end

  @doc """
  Two Crows: two black candles gapping up after a long white one, the
  third closing inside the first body.

      iex> TAlib.Indicators.CDL.two_crows([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec two_crows(list(map)) :: list(integer)
  def two_crows(bars),
    do:
      score(bars, 12, 3, fn [a, b, c] ->
        if white(a) and body_long(a) and black(b) and gap_up(b, a) and black(c) and
             c.o < b.o and c.o > b.c and c.c > a.o and c.c < a.c,
           do: -100,
           else: 0
      end)

  @doc """
  Three Black Crows: three long black candles opening inside the prior
  body, closing successively lower with very short lower shadows.

      iex> TAlib.Indicators.CDL.three_black_crows([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec three_black_crows(list(map)) :: list(integer)
  def three_black_crows(bars),
    do:
      score(bars, 13, 4, fn [w, a, b, c] ->
        if white(w) and black(a) and black(b) and black(c) and
             a.o < w.o and a.o > w.c and b.o < a.o and b.o > a.c and
             w.h > a.c and a.c > b.c and b.c > c.c and
             b.lo < shadow_very_short(b) and c.lo < shadow_very_short(c) and
             a.lo < shadow_very_short(a),
           do: -100,
           else: 0
      end)

  @doc """
  Three Inside: a long candle, a short candle engulfed by it, then a
  candle closing out in the opposite direction.

      iex> TAlib.Indicators.CDL.three_inside([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec three_inside(list(map)) :: list(integer)
  def three_inside(bars),
    do:
      score(bars, 12, 3, fn [a, b, c] ->
        opposite =
          (white(a) and black(c) and c.c < a.o) or (black(a) and white(c) and c.c > a.o)

        if maxb(b) < maxb(a) and minb(b) > minb(a) and opposite and
             body_long(a) and body_short(b),
           do: if(white(a), do: -100, else: 100),
           else: 0
      end)

  @doc """
  Three Line Strike: three same-color candles each opening near the
  prior body, undone by a fourth that opens beyond and closes across
  all three.

      iex> TAlib.Indicators.CDL.three_line_strike([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec three_line_strike(list(map)) :: list(integer)
  def three_line_strike(bars),
    do:
      score(bars, 8, 4, fn [a, b, c, d] ->
        same = white(a) == white(b) and white(b) == white(c) and white(d) != white(c)

        direction =
          if white(c) do
            c.c > b.c and b.c > a.c and d.o > c.c and d.c < a.o
          else
            c.c < b.c and b.c < a.c and d.o < c.c and d.c > a.o
          end

        if same and b.o >= minb(a) - near(a) and b.o <= maxb(a) + near(a) and
             c.o >= minb(b) - near(b) and c.o <= maxb(b) + near(b) and direction,
           do: if(white(c), do: 100, else: -100),
           else: 0
      end)

  @doc """
  Three Outside: an engulfing candle followed by a further close in
  the engulfing direction.

      iex> TAlib.Indicators.CDL.three_outside([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec three_outside(list(map)) :: list(integer)
  def three_outside(bars),
    do:
      score(bars, 3, 3, fn [a, b, c] ->
        bull = white(b) and black(a) and b.c > a.o and b.o < a.c and c.c > b.c
        bear = black(b) and white(a) and b.o > a.c and b.c < a.o and c.c < b.c

        if bull or bear, do: if(white(b), do: 100, else: -100), else: 0
      end)

  @doc """
  Three Stars in the South: three black candles — long with a long
  lower shadow, smaller inside it, then a small marubozu engulfed by
  the second.

      iex> TAlib.Indicators.CDL.three_stars_in_south([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec three_stars_in_south(list(map)) :: list(integer)
  def three_stars_in_south(bars),
    do:
      score(bars, 12, 3, fn [a, b, c] ->
        if black(a) and black(b) and black(c) and body_long(a) and
             a.lo > shadow_long(a) and
             b.body < a.body and b.o > a.c and b.o <= a.h and b.l < a.c and b.l >= a.l and
             b.lo > shadow_very_short(b) and
             not body_short(c) and c.lo < shadow_very_short(c) and
             c.up < shadow_very_short(c) and c.l > b.l and c.h < b.h,
           do: 100,
           else: 0
      end)

  @doc """
  Three Advancing White Soldiers: three white candles with consecutive
  higher closes, each opening near the prior body, none far shorter
  than its predecessor.

      iex> bars = Enum.map(0..11, fn _ -> %{open: 0.0, high: 2.0, low: 0.0, close: 1.0} end)
      iex> TAlib.Indicators.CDL.three_white_soldiers(bars) |> Enum.all?(&(&1 == 0))
      true
  """
  @spec three_white_soldiers(list(map)) :: list(integer)
  def three_white_soldiers(bars),
    do:
      score(bars, 12, 3, fn [a, b, c] ->
        if white(a) and a.up < shadow_very_short(a) and white(b) and
             b.up < shadow_very_short(b) and white(c) and c.up < shadow_very_short(c) and
             c.c > b.c and b.c > a.c and
             b.o > a.o and b.o <= a.c + near(a) and
             c.o > b.o and c.o <= b.c + near(b) and
             b.body > a.body - far(a) and c.body > b.body - far(b) and
             not body_short(c),
           do: 100,
           else: 0
      end)

  @doc """
  Abandoned Baby: a long candle, a doji gapping away from it, and a
  third candle gapping beyond the doji to close well within the first
  body.

      iex> TAlib.Indicators.CDL.abandoned_baby([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec abandoned_baby(list(map), number) :: list(integer)
  def abandoned_baby(bars, penetration \\ 0.3),
    do:
      score(bars, 12, 3, fn [a, b, c] ->
        bull =
          white(a) and black(c) and c.c < a.c - a.body * penetration and
            b.l > a.h and c.h < b.l

        bear =
          black(a) and white(c) and c.c > a.body * penetration + a.c and
            b.h < a.l and c.l > b.h

        if body_long(a) and doji_body(b) and not body_short(c) and (bull or bear),
          do: if(white(c), do: 100, else: -100),
          else: 0
      end)

  @doc """
  Advancing Block: three white candles with higher closes but stalling
  bodies or upper shadows.

      iex> TAlib.Indicators.CDL.advance_block([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec advance_block(list(map)) :: list(integer)
  def advance_block(bars),
    do:
      score(bars, 12, 3, fn [a, b, c] ->
        blocked =
          (b.body < a.body - far(a) and c.body < b.body + near(b)) or
            c.body < b.body - far(b) or
            (c.body < b.body and b.body < a.body and
               (c.up > shadow_short(c) or b.up > shadow_short(b))) or
            (c.body < b.body and c.up > shadow_long(c))

        if white(a) and white(b) and white(c) and
             c.c > b.c and b.c > a.c and
             b.o > a.o and b.o <= a.c + near(a) and
             c.o > b.o and c.o <= b.c + near(b) and
             body_long(a) and a.up < shadow_short(a) and blocked,
           do: -100,
           else: 0
      end)

  @doc """
  Belt Hold: a long-body candle with a very short shadow on the
  closing end.

      iex> bars = Enum.map(0..9, fn _ -> %{open: 0.0, high: 2.0, low: 0.0, close: 1.0} end)
      iex> TAlib.Indicators.CDL.belt_hold(bars) |> Enum.all?(&(&1 == 0))
      true
  """
  @spec belt_hold(list(map)) :: list(integer)
  def belt_hold(bars),
    do:
      score(bars, 10, 1, fn [b] ->
        shadowed =
          (white(b) and b.lo < shadow_very_short(b)) or
            (black(b) and b.up < shadow_very_short(b))

        if body_long(b) and shadowed, do: if(white(b), do: 100, else: -100), else: 0
      end)

  @doc """
  Breakaway: a gap and three drifting candles, then a long candle
  closing back inside the gap.

      iex> TAlib.Indicators.CDL.breakaway([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec breakaway(list(map)) :: list(integer)
  def breakaway(bars),
    do:
      score(bars, 14, 5, fn [a, b, c, d, e] ->
        colors =
          white(a) == white(b) and white(b) == white(d) and white(e) != white(d)

        bear =
          black(a) and gap_down(b, a) and c.h < b.h and c.l < b.l and
            d.h < c.h and d.l < c.l and e.c > b.o and e.c < a.c

        bull =
          white(a) and gap_up(b, a) and c.h > b.h and c.l > b.l and
            d.h > c.h and d.l > c.l and e.c < b.o and e.c > a.c

        if colors and body_long(a) and (bear or bull),
          do: if(white(e), do: 100, else: -100),
          else: 0
      end)

  @doc """
  Closing Marubozu: a long body with a very short shadow only on the
  closing end.

      iex> bars = Enum.map(0..9, fn _ -> %{open: 0.0, high: 2.0, low: 0.0, close: 1.0} end)
      iex> TAlib.Indicators.CDL.closing_marubozu(bars) |> Enum.all?(&(&1 == 0))
      true
  """
  @spec closing_marubozu(list(map)) :: list(integer)
  def closing_marubozu(bars),
    do:
      score(bars, 10, 1, fn [b] ->
        shadowed =
          (white(b) and b.up < shadow_very_short(b)) or
            (black(b) and b.lo < shadow_very_short(b))

        if body_long(b) and shadowed, do: if(white(b), do: 100, else: -100), else: 0
      end)

  @doc """
  Concealing Baby Swallow: two marubozu blacks, a gapping black with
  an upper shadow into the prior body, engulfed by the fourth black.

      iex> TAlib.Indicators.CDL.conceal_babys_wall([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec conceal_babys_wall(list(map)) :: list(integer)
  def conceal_babys_wall(bars),
    do:
      score(bars, 13, 4, fn [a, b, c, d] ->
        marubozu = fn x -> x.lo < shadow_very_short(x) and x.up < shadow_very_short(x) end

        if black(a) and black(b) and black(c) and black(d) and
             marubozu.(a) and marubozu.(b) and
             c.lo < shadow_very_short(c) and gap_down(c, b) and
             c.up > shadow_very_short(c) and c.h > b.c and
             d.h > c.h and d.l < c.l,
           do: 100,
           else: 0
      end)

  @doc """
  Counterattack: two opposite long candles closing at the same level.

      iex> TAlib.Indicators.CDL.counterattack([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec counterattack(list(map)) :: list(integer)
  def counterattack(bars),
    do:
      score(bars, 11, 2, fn [a, b] ->
        if white(a) != white(b) and body_long(a) and body_long(b) and
             b.c <= a.c + equal_tol(a) and b.c >= a.c - equal_tol(a),
           do: if(white(b), do: 100, else: -100),
           else: 0
      end)

  @doc """
  Dark Cloud Cover: a long white candle, then a black opening above
  its high and closing well within its body.

      iex> TAlib.Indicators.CDL.dark_cloud_cover([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec dark_cloud_cover(list(map), number) :: list(integer)
  def dark_cloud_cover(bars, penetration \\ 0.5),
    do:
      score(bars, 11, 2, fn [a, b] ->
        if white(a) and body_long(a) and black(b) and b.o > a.h and b.c > a.o and
             b.c < a.c - a.body * penetration,
           do: -100,
           else: 0
      end)

  @doc """
  Doji: a body no wider than 10% of the average high-low range of the
  10 previous candles.

      iex> bars = Enum.map(0..9, fn _ -> %{open: 0.0, high: 2.0, low: 0.0, close: 1.0} end)
      iex> TAlib.Indicators.CDL.doji(bars ++ [%{open: 1.0, high: 2.0, low: 0.0, close: 1.01}]) |> List.last()
      100
  """
  @spec doji(list(map)) :: list(integer)
  def doji(bars),
    do: score(bars, 10, 1, fn [b] -> if doji_body(b), do: 100, else: 0 end)

  @doc """
  Doji Star: a long candle then a doji gapping away from its body.

      iex> TAlib.Indicators.CDL.doji_star([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec doji_star(list(map)) :: list(integer)
  def doji_star(bars),
    do:
      score(bars, 11, 2, fn [a, b] ->
        gapped = (white(a) and gap_up(b, a)) or (black(a) and gap_down(b, a))

        if body_long(a) and doji_body(b) and gapped,
          do: if(white(a), do: -100, else: 100),
          else: 0
      end)

  @doc """
  Dragonfly Doji: a doji with a very short upper shadow and a lower
  shadow beyond the very-short band.

      iex> TAlib.Indicators.CDL.dragonfly_doji([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec dragonfly_doji(list(map)) :: list(integer)
  def dragonfly_doji(bars),
    do:
      score(bars, 10, 1, fn [b] ->
        if doji_body(b) and b.up < shadow_very_short(b) and
             b.lo > shadow_very_short(b),
           do: 100,
           else: 0
      end)

  @doc """
  Engulfing: a candle whose body engulfs the previous opposite-color
  body — `±80` when the touching bodies are merely equal.

      iex> TAlib.Indicators.CDL.engulfing([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec engulfing(list(map)) :: list(integer)
  def engulfing(bars),
    do:
      score(bars, 2, 2, fn [a, b] ->
        bull =
          white(b) and black(a) and
            ((b.c >= a.o and b.o < a.c) or (b.c > a.o and b.o <= a.c))

        bear =
          black(b) and white(a) and
            ((b.o >= a.c and b.c < a.o) or (b.o > a.c and b.c <= a.o))

        cond do
          not (bull or bear) -> 0
          b.o != a.c and b.c != a.o -> if white(b), do: 100, else: -100
          true -> if white(b), do: 80, else: -80
        end
      end)

  @doc """
  Evening Doji Star: a long white, a doji gapping up, then a black
  closing well within the first body.

      iex> TAlib.Indicators.CDL.evening_doji_star([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec evening_doji_star(list(map), number) :: list(integer)
  def evening_doji_star(bars, penetration \\ 0.3),
    do:
      score(bars, 12, 3, fn [a, b, c] ->
        if white(a) and black(c) and gap_up(b, a) and
             c.c < a.c - a.body * penetration and
             body_long(a) and doji_body(b) and not body_short(c),
           do: -100,
           else: 0
      end)

  @doc """
  Evening Star: a long white, a short candle gapping up, then a black
  closing well within the first body.

      iex> TAlib.Indicators.CDL.evening_star([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec evening_star(list(map), number) :: list(integer)
  def evening_star(bars, penetration \\ 0.3),
    do:
      score(bars, 12, 3, fn [a, b, c] ->
        if white(a) and black(c) and gap_up(b, a) and
             c.c < a.c - a.body * penetration and
             body_long(a) and body_short(b) and not body_short(c),
           do: -100,
           else: 0
      end)

  @doc """
  Upside/Downside Gap Side-by-Side White Lines: two white candles on
  the same side of a gap, of near-equal body and open.

      iex> TAlib.Indicators.CDL.gap_side_side_white([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec gap_side_side_white(list(map)) :: list(integer)
  def gap_side_side_white(bars),
    do:
      score(bars, 7, 3, fn [a, b, c] ->
        both =
          (gap_up(b, a) and gap_up(c, a)) or (gap_down(b, a) and gap_down(c, a))

        if both and white(b) and white(c) and
             c.body >= b.body - near(b) and c.body <= b.body + near(b) and
             c.o >= b.o - equal_tol(b) and c.o <= b.o + equal_tol(b),
           do: if(gap_up(b, a), do: 100, else: -100),
           else: 0
      end)

  @doc """
  Gravestone Doji: a doji with a very short lower shadow and an upper
  shadow beyond the very-short band.

      iex> TAlib.Indicators.CDL.gravestone_doji([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec gravestone_doji(list(map)) :: list(integer)
  def gravestone_doji(bars),
    do:
      score(bars, 10, 1, fn [b] ->
        if doji_body(b) and b.lo < shadow_very_short(b) and
             b.up > shadow_very_short(b),
           do: 100,
           else: 0
      end)

  @doc """
  Hammer: a small body near the prior candle's lows with a long lower
  shadow and a very short upper shadow.

      iex> TAlib.Indicators.CDL.hammer([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec hammer(list(map)) :: list(integer)
  def hammer(bars),
    do:
      score(bars, 11, 2, fn [a, b] ->
        if body_short(b) and b.lo > shadow_long(b) and b.up < shadow_very_short(b) and
             minb(b) <= a.l + near(a),
           do: 100,
           else: 0
      end)

  @doc """
  Hanging Man: a small body near the prior candle's highs with a long
  lower shadow and a very short upper shadow.

      iex> TAlib.Indicators.CDL.hanging_man([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec hanging_man(list(map)) :: list(integer)
  def hanging_man(bars),
    do:
      score(bars, 11, 2, fn [a, b] ->
        if body_short(b) and b.lo > shadow_long(b) and b.up < shadow_very_short(b) and
             minb(b) >= a.h - near(a),
           do: -100,
           else: 0
      end)

  @doc """
  Harami: a long candle then a short body inside it — `±80` when the
  short body merely touches the long body's ends.

      iex> TAlib.Indicators.CDL.harami([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec harami(list(map)) :: list(integer)
  def harami(bars),
    do:
      score(bars, 11, 2, fn [a, b] ->
        cond do
          not (body_long(a) and body_short(b)) ->
            0

          maxb(b) < maxb(a) and minb(b) > minb(a) ->
            if white(a), do: -100, else: 100

          maxb(b) <= maxb(a) and minb(b) >= minb(a) ->
            if white(a), do: -80, else: 80

          true ->
            0
        end
      end)

  @doc """
  Harami Cross: a long candle then a doji inside it — `±80` when the
  doji merely touches the long body's ends.

      iex> TAlib.Indicators.CDL.harami_cross([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec harami_cross(list(map)) :: list(integer)
  def harami_cross(bars),
    do:
      score(bars, 11, 2, fn [a, b] ->
        cond do
          not (body_long(a) and doji_body(b)) ->
            0

          maxb(b) < maxb(a) and minb(b) > minb(a) ->
            if white(a), do: -100, else: 100

          maxb(b) <= maxb(a) and minb(b) >= minb(a) ->
            if white(a), do: -80, else: 80

          true ->
            0
        end
      end)

  @doc """
  High Wave: a short body with both shadows longer than twice the
  body.

      iex> TAlib.Indicators.CDL.high_wave([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec high_wave(list(map)) :: list(integer)
  def high_wave(bars),
    do:
      score(bars, 10, 1, fn [b] ->
        if body_short(b) and b.up > shadow_very_long(b) and b.lo > shadow_very_long(b),
          do: if(white(b), do: 100, else: -100),
          else: 0
      end)

  @doc """
  Hikkake: an inside bar resolved by a breakout bar, with a `±200`
  confirmation when a close crosses the setup's extreme within three
  bars.

      iex> bars = [
      ...>   %{open: 1.0, high: 10.0, low: 0.0, close: 5.0},
      ...>   %{open: 1.0, high: 9.0, low: 1.0, close: 5.0},
      ...>   %{open: 1.0, high: 8.0, low: 0.5, close: 5.0},
      ...>   %{open: 1.0, high: 8.5, low: 0.6, close: 5.0},
      ...>   %{open: 1.0, high: 8.4, low: 0.7, close: 5.0},
      ...>   %{open: 1.0, high: 8.6, low: 0.65, close: 9.5}
      ...> ]
      iex> TAlib.Indicators.CDL.hikkake(bars)
      [0, 0, 0, 0, 0, 200]
  """
  @spec hikkake(list(map)) :: list(integer)
  def hikkake(bars) do
    tuple = List.to_tuple(bars)
    size = tuple_size(tuple)

    {_, state} =
      Enum.reduce(2..min(4, size - 1)//1, {[], {0, 0, nil, nil}}, fn i, {_, state} ->
        {_score, state} = hikkake_step(tuple, i, state, false)
        {nil, state}
      end)

    hikkake_outputs(tuple, state, size)
  end

  defp hikkake_outputs(_tuple, _state, size) when size <= 5,
    do: List.duplicate(0, size)

  defp hikkake_outputs(tuple, state, size) do
    {scores, _} =
      Enum.reduce(5..(size - 1)//1, {[], state}, fn i, {acc, state} ->
        {score, state} = hikkake_step(tuple, i, state, true)
        {[score | acc], state}
      end)

    List.duplicate(0, 5) ++ Enum.reverse(scores)
  end

  # One bar of the shared hikkake state machine: detection has
  # priority, confirmation follows while the counter is live.
  defp hikkake_step(tuple, i, {cd, result, saved_high, saved_low}, emit) do
    p2 = elem(tuple, i - 2)
    p1 = elem(tuple, i - 1)
    p0 = elem(tuple, i)

    detected =
      p1.high < p2.high and p1.low > p2.low and
        ((p0.high < p1.high and p0.low < p1.low) or
           (p0.high > p1.high and p0.low > p1.low))

    {score, cd, result, saved_high, saved_low} =
      if detected do
        result = if p0.high < p1.high, do: 100, else: -100
        {if(emit, do: result, else: nil), 4, result, p1.high, p1.low}
      else
        confirmed =
          cd > 0 and
            ((result > 0 and p0.close > saved_high) or
               (result < 0 and p0.close < saved_low))

        if confirmed do
          {if(emit, do: confirmed(result), else: nil), 0, result, saved_high, saved_low}
        else
          {if(emit, do: 0, else: nil), cd, result, saved_high, saved_low}
        end
      end

    cd = if cd > 0, do: cd - 1, else: cd
    {unwrap(score), {cd, result, saved_high, saved_low}}
  end

  defp confirmed(result), do: result + div(result, abs(result)) * 100

  defp unwrap(nil), do: 0
  defp unwrap(value), do: value

  @doc """
  Modified Hikkake: two consecutive inside bars with the second
  closing near its extreme, resolved by a breakout bar, with the same
  `±200` confirmation as `hikkake/1`.

      iex> TAlib.Indicators.CDL.hikkake_mod([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec hikkake_mod(list(map)) :: list(integer)
  def hikkake_mod(bars) do
    ctx = context(bars)
    tuple = List.to_tuple(ctx)
    size = tuple_size(tuple)

    if size <= 10 do
      List.duplicate(0, size)
    else
      {_, state} =
        Enum.reduce(7..9//1, {[], {0, 0, nil, nil}}, fn i, {_, state} ->
          {_score, state} = hikkake_mod_step(tuple, i, state, false)
          {nil, state}
        end)

      {scores, _} =
        Enum.reduce(10..(size - 1)//1, {[], state}, fn i, {acc, state} ->
          {score, state} = hikkake_mod_step(tuple, i, state, true)
          {[score | acc], state}
        end)

      List.duplicate(0, 10) ++ Enum.reverse(scores)
    end
  end

  defp hikkake_mod_step(tuple, i, {count, result, pattern_high, pattern_low}, emit) do
    p3 = elem(tuple, i - 3)
    p2 = elem(tuple, i - 2)
    p1 = elem(tuple, i - 1)
    p0 = elem(tuple, i)

    detected =
      p2.h < p3.h and p2.l > p3.l and p1.h < p2.h and p1.l > p2.l and
        ((p0.h < p1.h and p0.l < p1.l and p2.c <= p2.l + near(p2)) or
           (p0.h > p1.h and p0.l > p1.l and p2.c >= p2.h - near(p2)))

    {score, count, result, pattern_high, pattern_low} =
      if detected do
        result = if p0.h < p1.h, do: 100, else: -100
        {if(emit, do: result, else: nil), 4, result, p1.h, p1.l}
      else
        confirmed =
          count > 0 and
            ((result > 0 and p0.c > pattern_high) or
               (result < 0 and p0.c < pattern_low))

        if confirmed do
          {if(emit, do: confirmed(result), else: nil), 0, result, pattern_high, pattern_low}
        else
          {if(emit, do: 0, else: nil), count, result, pattern_high, pattern_low}
        end
      end

    count = if count > 0, do: count - 1, else: count
    {unwrap(score), {count, result, pattern_high, pattern_low}}
  end

  @doc """
  Homing Pigeon: a long black candle then a smaller black body inside
  it.

      iex> TAlib.Indicators.CDL.homing_pigeon([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec homing_pigeon(list(map)) :: list(integer)
  def homing_pigeon(bars),
    do:
      score(bars, 11, 2, fn [a, b] ->
        if black(a) and black(b) and body_long(a) and body_short(b) and
             b.o < a.o and b.c > a.c,
           do: 100,
           else: 0
      end)

  @doc """
  Identical Three Crows: three black candles with very short lower
  shadows, each opening at the prior close and closing lower.

      iex> TAlib.Indicators.CDL.identical_3_crows([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec identical_3_crows(list(map)) :: list(integer)
  def identical_3_crows(bars),
    do:
      score(bars, 12, 3, fn [a, b, c] ->
        if black(a) and a.lo < shadow_very_short(a) and
             black(b) and b.lo < shadow_very_short(b) and
             black(c) and c.lo < shadow_very_short(c) and
             a.c > b.c and b.c > c.c and
             b.o <= a.c + equal_tol(a) and b.o >= a.c - equal_tol(a) and
             c.o <= b.c + equal_tol(b) and c.o >= b.c - equal_tol(b),
           do: -100,
           else: 0
      end)

  @doc """
  In Neck: a long black, then a white opening below its low and
  closing marginally into its body.

      iex> TAlib.Indicators.CDL.in_neck([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec in_neck(list(map)) :: list(integer)
  def in_neck(bars),
    do:
      score(bars, 11, 2, fn [a, b] ->
        if black(a) and body_long(a) and white(b) and b.o < a.l and
             b.c <= a.c + equal_tol(a) and b.c >= a.c,
           do: -100,
           else: 0
      end)

  @doc """
  Inverted Hammer: after a gap down, a small body with a long upper
  shadow and a very short lower shadow.

      iex> TAlib.Indicators.CDL.inverted_hammer([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec inverted_hammer(list(map)) :: list(integer)
  def inverted_hammer(bars),
    do:
      score(bars, 11, 2, fn [a, b] ->
        if gap_down(b, a) and body_short(b) and b.up > shadow_long(b) and
             b.lo < shadow_very_short(b),
           do: 100,
           else: 0
      end)

  @doc """
  Kicking: two opposite marubozu candles separated by a body gap.

      iex> TAlib.Indicators.CDL.kicking([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec kicking(list(map)) :: list(integer)
  def kicking(bars),
    do:
      score(bars, 11, 2, fn [a, b] ->
        marubozu = fn x ->
          body_long(x) and x.up < shadow_very_short(x) and x.lo < shadow_very_short(x)
        end

        gapped = (black(a) and b.l > a.h) or (white(a) and b.h < a.l)

        if white(a) != white(b) and marubozu.(a) and marubozu.(b) and gapped,
          do: if(white(b), do: 100, else: -100),
          else: 0
      end)

  @doc """
  Kicking (determined by length): as `kicking/1`, scored by the color
  of the longer body.

      iex> TAlib.Indicators.CDL.kicking_by_length([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec kicking_by_length(list(map)) :: list(integer)
  def kicking_by_length(bars),
    do:
      score(bars, 11, 2, fn [a, b] ->
        marubozu = fn x ->
          body_long(x) and x.up < shadow_very_short(x) and x.lo < shadow_very_short(x)
        end

        gapped = (black(a) and b.l > a.h) or (white(a) and b.h < a.l)
        winner = if b.body > a.body, do: b, else: a

        if white(a) != white(b) and marubozu.(a) and marubozu.(b) and gapped,
          do: if(white(winner), do: 100, else: -100),
          else: 0
      end)

  @doc """
  Ladder Bottom: three blacks with lower opens and closes, a black
  with an upper shadow, then a white closing above its high.

      iex> TAlib.Indicators.CDL.ladder_bottom([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec ladder_bottom(list(map)) :: list(integer)
  def ladder_bottom(bars),
    do:
      score(bars, 14, 5, fn [a, b, c, d, e] ->
        if black(a) and black(b) and black(c) and
             a.o > b.o and b.o > c.o and a.c > b.c and b.c > c.c and
             black(d) and d.up > shadow_very_short(d) and
             white(e) and e.o > d.o and e.c > d.h,
           do: 100,
           else: 0
      end)

  @doc """
  Long Legged Doji: a doji with at least one shadow longer than its
  own body.

      iex> TAlib.Indicators.CDL.long_legged_doji([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec long_legged_doji(list(map)) :: list(integer)
  def long_legged_doji(bars),
    do:
      score(bars, 10, 1, fn [b] ->
        if doji_body(b) and (b.lo > shadow_long(b) or b.up > shadow_long(b)),
          do: 100,
          else: 0
      end)

  @doc """
  Long Line: a long body with short shadows on both ends.

      iex> bars = Enum.map(0..9, fn _ -> %{open: 0.0, high: 2.0, low: 0.0, close: 1.0} end)
      iex> TAlib.Indicators.CDL.long_line(bars) |> Enum.all?(&(&1 == 0))
      true
  """
  @spec long_line(list(map)) :: list(integer)
  def long_line(bars),
    do:
      score(bars, 10, 1, fn [b] ->
        if body_long(b) and b.up < shadow_short(b) and b.lo < shadow_short(b),
          do: if(white(b), do: 100, else: -100),
          else: 0
      end)

  @doc """
  Marubozu: a long body with very short shadows on both ends.

      iex> bars = Enum.map(0..9, fn _ -> %{open: 0.0, high: 2.0, low: 0.0, close: 1.0} end)
      iex> TAlib.Indicators.CDL.marubozu(bars) |> Enum.all?(&(&1 == 0))
      true
  """
  @spec marubozu(list(map)) :: list(integer)
  def marubozu(bars),
    do:
      score(bars, 10, 1, fn [b] ->
        if body_long(b) and b.up < shadow_very_short(b) and b.lo < shadow_very_short(b),
          do: if(white(b), do: 100, else: -100),
          else: 0
      end)

  @doc """
  Matching Low: two black candles closing at the same level.

      iex> TAlib.Indicators.CDL.matching_low([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec matching_low(list(map)) :: list(integer)
  def matching_low(bars),
    do:
      score(bars, 6, 2, fn [a, b] ->
        if black(a) and black(b) and
             b.c <= a.c + equal_tol(a) and b.c >= a.c - equal_tol(a),
           do: 100,
           else: 0
      end)

  @doc """
  Mat Hold: a long white, a gap and three small drifting candles
  holding within it, then a white closing above the reaction highs.

      iex> TAlib.Indicators.CDL.mat_hold([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec mat_hold(list(map), number) :: list(integer)
  def mat_hold(bars, penetration \\ 0.5),
    do:
      score(bars, 14, 5, fn [a, b, c, d, e] ->
        if white(a) and black(b) and white(e) and gap_up(b, a) and
             minb(c) < a.c and minb(d) < a.c and
             minb(c) > a.c - a.body * penetration and
             minb(d) > a.c - a.body * penetration and
             maxb(c) < b.o and maxb(d) < maxb(c) and
             e.o > d.c and e.c > max(max(b.h, c.h), d.h) and
             body_long(a) and body_short(b) and body_short(c) and body_short(d),
           do: 100,
           else: 0
      end)

  @doc """
  Morning Doji Star: a long black, a doji gapping down, then a white
  closing well within the first body.

      iex> TAlib.Indicators.CDL.morning_doji_star([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec morning_doji_star(list(map), number) :: list(integer)
  def morning_doji_star(bars, penetration \\ 0.3),
    do:
      score(bars, 12, 3, fn [a, b, c] ->
        if black(a) and white(c) and gap_down(b, a) and
             c.c > a.body * penetration + a.c and
             body_long(a) and doji_body(b) and not body_short(c),
           do: 100,
           else: 0
      end)

  @doc """
  Morning Star: a long black, a short candle gapping down, then a
  white closing well within the first body.

      iex> TAlib.Indicators.CDL.morning_star([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec morning_star(list(map), number) :: list(integer)
  def morning_star(bars, penetration \\ 0.3),
    do:
      score(bars, 12, 3, fn [a, b, c] ->
        if black(a) and white(c) and gap_down(b, a) and
             c.c > a.body * penetration + a.c and
             body_long(a) and body_short(b) and not body_short(c),
           do: 100,
           else: 0
      end)

  @doc """
  On Neck: a long black, then a white opening below its low and
  closing at its low.

      iex> TAlib.Indicators.CDL.on_neck([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec on_neck(list(map)) :: list(integer)
  def on_neck(bars),
    do:
      score(bars, 11, 2, fn [a, b] ->
        if black(a) and body_long(a) and white(b) and b.o < a.l and
             b.c <= a.l + equal_tol(a) and b.c >= a.l - equal_tol(a),
           do: -100,
           else: 0
      end)

  @doc """
  Piercing Line: a long black, then a white opening below its low and
  closing above the midpoint of its body.

      iex> TAlib.Indicators.CDL.piercing([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec piercing(list(map), number) :: list(integer)
  def piercing(bars, penetration \\ 0.5),
    do:
      score(bars, 11, 2, fn [a, b] ->
        if black(a) and body_long(a) and white(b) and body_long(b) and
             b.o < a.l and b.c < a.o and b.c > a.body * penetration + a.c,
           do: 100,
           else: 0
      end)

  @doc """
  Rickshaw Man: a doji with long shadows on both sides and the body
  near the midpoint of the range.

      iex> TAlib.Indicators.CDL.rickshaw_man([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec rickshaw_man(list(map)) :: list(integer)
  def rickshaw_man(bars),
    do:
      score(bars, 10, 1, fn [b] ->
        midpoint = b.l + (b.h - b.l) / 2

        if doji_body(b) and b.lo > shadow_long(b) and b.up > shadow_long(b) and
             minb(b) <= midpoint + near(b) and maxb(b) >= midpoint - near(b),
           do: 100,
           else: 0
      end)

  @doc """
  Rising/Falling Three Methods: a long candle, three small bodies
  drifting within it, then a long candle closing the move.

      iex> TAlib.Indicators.CDL.rise_fall_3_methods([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec rise_fall_3_methods(list(map)) :: list(integer)
  def rise_fall_3_methods(bars),
    do:
      score(bars, 14, 5, fn [a, b, c, d, e] ->
        colors =
          white(a) != white(b) and white(b) == white(c) and white(c) == white(d) and
            white(d) != white(e)

        hold =
          Enum.all?([b, c, d], fn x -> minb(x) < a.h and maxb(x) > a.l end)

        drift =
          if white(a) do
            c.c < b.c and d.c < c.c and e.o > d.c and e.c > a.c
          else
            c.c > b.c and d.c > c.c and e.o < d.c and e.c < a.c
          end

        if colors and hold and drift and
             body_long(a) and body_short(b) and body_short(c) and body_short(d) and
             body_long(e),
           do: if(white(a), do: 100, else: -100),
           else: 0
      end)

  @doc """
  Separating Lines: two opposite candles opening at the same level,
  the second a belt-hold candle.

      iex> TAlib.Indicators.CDL.separating_lines([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec separating_lines(list(map)) :: list(integer)
  def separating_lines(bars),
    do:
      score(bars, 11, 2, fn [a, b] ->
        belt =
          (white(b) and b.lo < shadow_very_short(b)) or
            (black(b) and b.up < shadow_very_short(b))

        if white(a) != white(b) and
             b.o <= a.o + equal_tol(a) and b.o >= a.o - equal_tol(a) and
             body_long(b) and belt,
           do: if(white(b), do: 100, else: -100),
           else: 0
      end)

  @doc """
  Shooting Star: after a body gap up, a small body with a long upper
  shadow and a very short lower shadow.

      iex> TAlib.Indicators.CDL.shooting_star([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec shooting_star(list(map)) :: list(integer)
  def shooting_star(bars),
    do:
      score(bars, 11, 2, fn [a, b] ->
        if gap_up(b, a) and body_short(b) and b.up > shadow_long(b) and
             b.lo < shadow_very_short(b),
           do: -100,
           else: 0
      end)

  @doc """
  Short Line: a short body with short shadows on both ends.

      iex> bars = Enum.map(0..9, fn _ -> %{open: 0.0, high: 2.0, low: 0.0, close: 1.0} end)
      iex> TAlib.Indicators.CDL.short_line(bars) |> Enum.all?(&(&1 == 0))
      true
  """
  @spec short_line(list(map)) :: list(integer)
  def short_line(bars),
    do:
      score(bars, 10, 1, fn [b] ->
        if body_short(b) and b.up < shadow_short(b) and b.lo < shadow_short(b),
          do: if(white(b), do: 100, else: -100),
          else: 0
      end)

  @doc """
  Spinning Top: a short body with both shadows longer than the body
  itself.

      iex> TAlib.Indicators.CDL.spinning_top([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec spinning_top(list(map)) :: list(integer)
  def spinning_top(bars),
    do:
      score(bars, 10, 1, fn [b] ->
        if b.up > b.body and b.lo > b.body and body_short(b),
          do: if(white(b), do: 100, else: -100),
          else: 0
      end)

  @doc """
  Stalled Pattern: two long whites advancing, then a small body
  riding on the second candle's shoulder.

      iex> TAlib.Indicators.CDL.stalled_pattern([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec stalled_pattern(list(map)) :: list(integer)
  def stalled_pattern(bars),
    do:
      score(bars, 12, 3, fn [a, b, c] ->
        if white(a) and white(b) and white(c) and
             c.c > b.c and b.c > a.c and
             body_long(a) and body_long(b) and
             b.up < shadow_very_short(b) and
             b.o > a.o and b.o <= a.c + near(a) and
             body_short(c) and
             c.o >= b.c - c.body - near(b),
           do: -100,
           else: 0
      end)

  @doc """
  Stick Sandwich: two blacks around a white whose low holds above the
  first close, the closes matching.

      iex> TAlib.Indicators.CDL.stick_sandwich([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec stick_sandwich(list(map)) :: list(integer)
  def stick_sandwich(bars),
    do:
      score(bars, 7, 3, fn [a, b, c] ->
        if black(a) and white(b) and black(c) and b.l > a.c and
             c.c <= a.c + equal_tol(a) and c.c >= a.c - equal_tol(a),
           do: 100,
           else: 0
      end)

  @doc """
  Takuri: a doji with a very short upper shadow and a lower shadow
  longer than twice the body.

      iex> TAlib.Indicators.CDL.takuri([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec takuri(list(map)) :: list(integer)
  def takuri(bars),
    do:
      score(bars, 10, 1, fn [b] ->
        if doji_body(b) and b.up < shadow_very_short(b) and
             b.lo > shadow_very_long(b),
           do: 100,
           else: 0
      end)

  @doc """
  Tasuki Gap: a gap then a candle opening inside the gap-closing
  direction with a near-equal body, closing inside the gap.

      iex> TAlib.Indicators.CDL.tasuki_gap([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec tasuki_gap(list(map)) :: list(integer)
  def tasuki_gap(bars),
    do:
      score(bars, 7, 3, fn [a, b, c] ->
        up =
          gap_up(b, a) and white(b) and black(c) and
            c.o < b.c and c.o > b.o and c.c < b.o and c.c > maxb(a) and
            abs(b.body - c.body) < near(b)

        down =
          gap_down(b, a) and black(b) and white(c) and
            c.o < b.o and c.o > b.c and c.c > b.o and c.c < minb(a) and
            abs(b.body - c.body) < near(b)

        if up or down, do: if(white(b), do: 100, else: -100), else: 0
      end)

  @doc """
  Thrusting: a long black, then a white opening below its low and
  closing into but under the midpoint of its body.

      iex> TAlib.Indicators.CDL.thrusting([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec thrusting(list(map)) :: list(integer)
  def thrusting(bars),
    do:
      score(bars, 11, 2, fn [a, b] ->
        if black(a) and body_long(a) and white(b) and b.o < a.l and
             b.c > a.c + equal_tol(a) and b.c <= a.body * 0.5 + a.c,
           do: -100,
           else: 0
      end)

  @doc """
  Tristar: three dojis, the second gapping away and the third failing
  to extend the gap.

      iex> TAlib.Indicators.CDL.tristar([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec tristar(list(map)) :: list(integer)
  def tristar(bars),
    do:
      score(bars, 12, 3, fn [a, b, c] ->
        if doji_body(a) and b.body <= 0.1 * (a.hl10 / 10) and
             c.body <= 0.1 * (a.hl10 / 10) do
          cond do
            gap_up(b, a) and maxb(c) < maxb(b) -> -100
            gap_down(b, a) and minb(c) > minb(b) -> 100
            true -> 0
          end
        else
          0
        end
      end)

  @doc """
  Unique Three River: a long black, a black harami with a lower low,
  then a small white opening off the low.

      iex> TAlib.Indicators.CDL.unique_3_river([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec unique_3_river(list(map)) :: list(integer)
  def unique_3_river(bars),
    do:
      score(bars, 12, 3, fn [a, b, c] ->
        if black(a) and black(b) and white(c) and
             b.c > a.c and b.o <= a.o and b.l < a.l and c.o > b.l and
             body_long(a) and body_short(c),
           do: 100,
           else: 0
      end)

  @doc """
  Upside Gap Two Crows: a long white, then two blacks gapping up with
  the third engulfing the second but closing above the first.

      iex> TAlib.Indicators.CDL.upside_gap_2crows([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec upside_gap_2crows(list(map)) :: list(integer)
  def upside_gap_2crows(bars),
    do:
      score(bars, 12, 3, fn [a, b, c] ->
        if white(a) and body_long(a) and black(b) and body_short(b) and
             gap_up(b, a) and black(c) and
             c.o > b.o and c.c < b.c and c.c > a.c,
           do: -100,
           else: 0
      end)

  @doc """
  Upside/Downside Gap Three Methods: a gap between two same-color
  candles, partially closed by a third of the opposite color.

      iex> TAlib.Indicators.CDL.xside_gap_3methods([%{open: 1, high: 2, low: 0.5, close: 1.5}])
      [0]
  """
  @spec xside_gap_3methods(list(map)) :: list(integer)
  def xside_gap_3methods(bars),
    do:
      score(bars, 2, 3, fn [a, b, c] ->
        gapped = (white(a) and gap_up(b, a)) or (black(a) and gap_down(b, a))

        if white(a) == white(b) and white(b) != white(c) and
             c.o < maxb(b) and c.o > minb(b) and
             c.c < maxb(a) and c.c > minb(a) and gapped,
           do: if(white(a), do: 100, else: -100),
           else: 0
      end)
end
