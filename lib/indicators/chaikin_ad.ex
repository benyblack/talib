defmodule TAlib.Indicators.ChaikinAD do
  alias TAlib.Indicators.MA

  @moduledoc """
  Chaikin Accumulation/Distribution line and oscillator.

  With the Close Location Value
  `CLV = ((close - low) - (high - close)) / (high - low)`:

  * `AD` accumulates `CLV * volume` across bars (zero-range bars
    contribute nothing)
  * `ADOSC = EMA(CLV * volume, fast) - EMA(CLV * volume, slow)`

  Bars are maps with at least `:high`, `:low`, `:close` and `:volume`.
  See `TAlib` for the conventions.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  The latest value of the Chaikin A/D line.

  ## Parameters

    - bars: list of bars, oldest first.

  ## Examples

      iex> TAlib.Indicators.ChaikinAD.ad([
      ...>   %{high: 11, low: 9, close: 10, volume: 100},
      ...>   %{high: 12, low: 8, close: 11, volume: 200}
      ...> ])
      100.0
  """
  @spec ad(list(map)) :: float | nil
  def ad([]), do: nil

  def ad(bars) when is_list(bars), do: List.last(ad_list(bars))

  @doc """
  The Chaikin A/D line for every bar.

      iex> TAlib.Indicators.ChaikinAD.ad_list([
      ...>   %{high: 11, low: 9, close: 10, volume: 100},
      ...>   %{high: 12, low: 8, close: 11, volume: 200}
      ...> ])
      [0.0, 100.0]
  """
  @spec ad_list(list(map)) :: list(float)
  def ad_list([]), do: []

  def ad_list(bars) when is_list(bars) do
    {series, _final_total} =
      Enum.map_reduce(bars, 0.0, fn bar, total ->
        flow = money_flow(bar)
        {total + flow, total + flow}
      end)

    series
  end

  @doc """
  The Chaikin A/D oscillator: `EMA(flow, fast) - EMA(flow, slow)`,
  defined from index `slow - 1` on.

  ## Parameters

    - bars: list of bars, oldest first.
    - fast: fast EMA period, a positive integer (default 3).
    - slow: slow EMA period, a positive integer (default 10).

  ## Examples

      iex> TAlib.Indicators.ChaikinAD.adosc(
      ...>   [
      ...>     %{high: 11, low: 9, close: 10, volume: 100},
      ...>     %{high: 12, low: 8, close: 11, volume: 200}
      ...>   ],
      ...>   2,
      ...>   2
      ...> )
      0.0
  """
  @spec adosc(list(map), pos_integer, pos_integer) :: float | nil
  def adosc(bars, fast \\ 3, slow \\ 10)

  def adosc(_bars, fast, _slow) when not is_valid_period(fast), do: TAlib.invalid_period!(fast)

  def adosc(_bars, _fast, slow) when not is_valid_period(slow), do: TAlib.invalid_period!(slow)

  def adosc(bars, _fast, slow) when is_list(bars) and length(bars) < slow, do: nil

  def adosc(bars, fast, slow) when is_list(bars) do
    flows = Enum.map(bars, &money_flow/1)
    MA.ema(flows, fast) - MA.ema(flows, slow)
  end

  defp money_flow(%{high: high, low: low, close: close, volume: volume}) do
    range = high - low

    if range == 0 do
      0.0
    else
      clv = (close - low - (high - close)) / range
      clv * volume
    end
  end
end
