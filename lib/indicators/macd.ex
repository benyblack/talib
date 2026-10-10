defmodule TAlib.Indicators.MACD do
  alias TAlib.Indicators.MA

  @moduledoc """
  MACD indicator [Wikipedia](https://en.wikipedia.org/wiki/MACD).

  Calculates the MACD line, the signal line and the histogram. See `TAlib`
  for the input conventions: prices are given newest first. Every function
  returns `nil` when there is not enough data.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate the MACD line: `EMA(prices, fast) - EMA(prices, slow)`.

  ## Parameters

    - prices: list of prices, newest first.
    - fast: period of the fast EMA (default 12).
    - slow: period of the slow EMA (default 26).

  ## Examples

      iex> TAlib.Indicators.MACD.macd([6, 2, 5, 3, 4, 1], 3, 2) |> Float.round(4)
      -0.4614
  """
  @spec macd(list(number), pos_integer, pos_integer) :: float | nil
  def macd(prices, fast \\ 12, slow \\ 26)

  def macd(_prices, fast, _slow) when not is_valid_period(fast), do: TAlib.invalid_period!(fast)

  def macd(_prices, _fast, slow) when not is_valid_period(slow), do: TAlib.invalid_period!(slow)

  def macd(prices, fast, slow)
      when is_list(prices) and (length(prices) < slow * 2 or length(prices) < fast * 2),
      do: nil

  def macd(prices, fast, slow) when is_list(prices),
    do: MA.ema(prices, fast) - MA.ema(prices, slow)

  @doc """
  Calculate the signal line: an EMA with the given `period` over the MACD
  series of the last `period * 2` windows.

  ## Parameters

    - prices: list of prices, newest first.
    - period: EMA period applied to the MACD series (default 9).
    - fast: period of the fast MACD EMA (default 12).
    - slow: period of the slow MACD EMA (default 26).

  At least `slow * 2 + period * 2 - 1` prices are required for every MACD
  value in the signal window to be defined; otherwise `nil` is returned.

  ## Examples

      iex> TAlib.Indicators.MACD.signal([9, 2, 8, 3, 7, 4, 6, 1, 5], 2, 3, 2) |> Float.round(4)
      -0.3441
  """
  @spec signal(list(number), pos_integer, pos_integer, pos_integer) :: float | nil
  def signal(prices, period \\ 9, fast \\ 12, slow \\ 26)

  def signal(_prices, period, _fast, _slow) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def signal(_prices, _period, fast, _slow) when not is_valid_period(fast),
    do: TAlib.invalid_period!(fast)

  def signal(_prices, _period, _fast, slow) when not is_valid_period(slow),
    do: TAlib.invalid_period!(slow)

  def signal(prices, period, _fast, slow)
      when is_list(prices) and length(prices) < slow * 2 + period * 2 - 1,
      do: nil

  def signal(prices, period, fast, slow) when is_list(prices) do
    # MACD of each of the last period*2 windows, newest first.
    macd_list =
      Enum.map(0..(period * 2 - 1), fn x ->
        macd(Enum.slice(prices, x, length(prices)), fast, slow)
      end)

    MA.ema(macd_list, period)
  end

  @doc """
  Calculate the MACD histogram: MACD line minus signal line.

  ## Parameters

    - prices: list of prices, newest first.
    - macd_fast: fast EMA period of the MACD line (default 12).
    - macd_slow: slow EMA period of the MACD line (default 26).
    - signal_period: EMA period of the signal line (default 9).

  ## Examples

      iex> TAlib.Indicators.MACD.histogram([9, 2, 8, 3, 7, 4, 6, 1, 5], 3, 2, 2) |> Float.round(4)
      -0.3112
  """
  @spec histogram(list(number), pos_integer, pos_integer, pos_integer) :: float | nil
  def histogram(prices, macd_fast \\ 12, macd_slow \\ 26, signal_period \\ 9)

  def histogram(_prices, macd_fast, _macd_slow, _signal_period)
      when not is_valid_period(macd_fast),
      do: TAlib.invalid_period!(macd_fast)

  def histogram(_prices, _macd_fast, macd_slow, _signal_period)
      when not is_valid_period(macd_slow),
      do: TAlib.invalid_period!(macd_slow)

  def histogram(_prices, _macd_fast, _macd_slow, signal_period)
      when not is_valid_period(signal_period),
      do: TAlib.invalid_period!(signal_period)

  def histogram(prices, macd_fast, macd_slow, signal_period)
      when is_list(prices) and
             (length(prices) < macd_slow * 2 + signal_period * 2 - 1 or
                length(prices) < macd_fast * 2),
      do: nil

  def histogram(prices, macd_fast, macd_slow, signal_period) when is_list(prices) do
    macd(prices, macd_fast, macd_slow) - signal(prices, signal_period, macd_fast, macd_slow)
  end
end
