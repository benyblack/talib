defmodule TAlib.Indicators.MACD do
  alias TAlib.Indicators.MA

  @moduledoc """
  MACD indicator [https://en.wikipedia.org/wiki/MACD]
  Calculate MACD, Signal line, and Histogram
  """

  @doc """
  Calculate MACD

  ## Parameters
    - prices: List of prices, lates price is the first one in the list.
    - fast: Period of slow ema calculation. Default is 12.
    - slow: Period of fast ema calculation. Default is 26.

  ## Example
    ```
      iex> prices = [1330.95, 1334.65, 1340, 1338.7, ...]
      iex> TAlib.Indicators.MACD.macd(prices)
      20.36269273502262
    ```
  """
  def macd(prices, fast \\ 12, slow \\ 26)
  def macd(prices, _fast, slow) when is_list(prices) and length(prices)<(slow*2), do: 0
  def macd(prices, fast, slow) when is_list(prices) do
    MA.ema(prices, fast) - MA.ema(prices, slow)
  end


  @doc """
  Calculate Signal line

  ## Parameters
    - prices: List of prices, lates price is the first one in the list.
    - period: Period of ema calculation on macd line. Default is 9.

  ## Example
  ```
      iex> prices = [1330.95, 1334.65, 1340, 1338.7, ...]
      iex> TAlib.Indicators.MACD.signal(prices)
      12.280523570457825
  ```
  """
  def signal(prices, period \\ 9)
  def signal(prices, period) when is_list(prices) and length(prices) < (period*2-1), do: 0
  def signal(prices, period) when is_list(prices) do
    # needed for calculating MACD for each 9 days of the period
    counter = 0..period*2-1
    macd_list = Enum.map(counter, fn(x) ->
      macd(Enum.slice(prices, x, length(prices)))
    end)
    MA.ema(macd_list, 9)
  end

  @doc """
  Calculate MACD Histogram which is (MACD Line - Signal Line)
  ## Parameters
    - prices: List of prices, lates price is the first one in the list.
    - macd_fast: Period of slow ema calculation. Default is 12.
    - macd_slow: Period of fast ema calculation. Default is 26.
    - signal_period: Period of ema calculation on macd line. Default is 9.

  ## Example
  ```
      iex> prices = [1330.95, 1334.65, 1340, 1338.7, ...]
      iex> TAlib.Indicators.MACD.histogram(prices)
      8.082169164564794
  ```
  """
  def histogram(prices, macd_fast \\ 12, macd_slow \\ 26, signal_period \\ 9)
  def histogram(prices, _macd_fast, macd_slow, _signal_period) when is_list(prices) and length(prices) < (macd_slow*2), do: 0
  def histogram(prices, _macd_fast, _macd_slow, signal_period) when is_list(prices) and length(prices) < (signal_period*2-1), do: 0
  def histogram(prices, macd_fast, macd_slow, signal_period) when is_list(prices) do
    macd(prices, macd_fast, macd_slow) - signal(prices, signal_period)
  end

end
