defmodule TAlib.Indicators.MAMA do
  @moduledoc """
  MESA Adaptive Moving Average (TA-Lib MAMA), translated from the TA-Lib
  C reference implementation of John Ehlers' MESA machinery.

  The alpha of the exponential average adapts to the phase rate of the
  Hilbert-transformed price: it moves at `fast_limit` when the phase
  rate is at or below one degree per bar (trending) and slows toward
  `slow_limit` as the phase rate rises. `fama` is MAMA itself averaged
  again with half the alpha.

  Like `TAlib.Indicators.HT` (the 32-lookback family: `ht_dcperiod`,
  `ht_phasor`), the first 32 entries are `nil`; TA-Lib's configurable
  unstable-period machinery is not mirrored. See `TAlib` for the
  conventions.
  """

  @doc """
  Calculate the MAMA and FAMA series as a map.

  ## Parameters

    - prices: list of prices, oldest first.
    - fast_limit: maximum alpha, between 0.01 and 0.99 (default 0.5).
    - slow_limit: minimum alpha, between 0.01 and 0.99 (default 0.05).

  ## Examples

      iex> values = TAlib.Indicators.MAMA.mama(Enum.to_list(1..100))
      iex> Float.round(List.last(values.mama), 4)
      95.7327
  """
  @spec mama(list(number), number, number) :: %{mama: list(float | nil), fama: list(float | nil)}
  def mama(prices, fast_limit \\ 0.5, slow_limit \\ 0.05)

  def mama(_prices, fast_limit, _slow_limit) when fast_limit < 0.01 or fast_limit > 0.99,
    do:
      raise(
        ArgumentError,
        "fast_limit must be between 0.01 and 0.99, got: #{inspect(fast_limit)}"
      )

  def mama(_prices, _fast_limit, slow_limit) when slow_limit < 0.01 or slow_limit > 0.99,
    do:
      raise(
        ArgumentError,
        "slow_limit must be between 0.01 and 0.99, got: #{inspect(slow_limit)}"
      )

  def mama(prices, _fast_limit, _slow_limit) when is_list(prices) and length(prices) < 64,
    do: %{mama: List.duplicate(nil, length(prices)), fama: List.duplicate(nil, length(prices))}

  def mama(prices, fast_limit, slow_limit) when is_list(prices) do
    alias TAlib.Indicators.HT

    {_tuple, stream} = HT.core_stream(prices, 12)

    {values, _acc} =
      HT.scan(stream, {0.0, 0.0, 0.0}, 32, fn bar, {prev_phase, mama, fama} ->
        {q1, i1_prev3} = HT.bar_q1_i1(bar)
        {alpha, phase} = adaptive_alpha(q1, i1_prev3, prev_phase, fast_limit, slow_limit)

        mama = (1 - alpha) * mama + alpha * HT.bar_price(bar)
        half = alpha * 0.5
        fama = (1 - half) * fama + half * mama

        {{mama, fama}, {phase, mama, fama}}
      end)

    values
    |> HT.align(12)
    |> then(&unzip(&1, :mama, :fama))
  end

  defp adaptive_alpha(q1, i1_prev3, prev_phase, fast_limit, slow_limit) do
    phase =
      if i1_prev3 != 0.0,
        do: :math.atan(q1 / i1_prev3) * (45 / :math.atan(1)),
        else: 0.0

    delta = prev_phase - phase

    alpha =
      cond do
        delta < 1.0 ->
          fast_limit

        true ->
          clamped = fast_limit / delta
          if clamped < slow_limit, do: slow_limit, else: clamped
      end

    {alpha, phase}
  end

  defp unzip(aligned, first_key, second_key) do
    {firsts, seconds} =
      Enum.reduce(aligned, {[], []}, fn
        nil, {f, s} -> {[nil | f], [nil | s]}
        {a, b}, {f, s} -> {[a | f], [b | s]}
      end)

    %{first_key => Enum.reverse(firsts), second_key => Enum.reverse(seconds)}
  end
end
