defmodule TAlib.Indicators.MA do
  @moduledoc """
  Moving Average indicator [Wikipedia](https://en.wikipedia.org/wiki/Moving_average)
  Calculate SMA, WMA, and EMA
  """

  @doc """
  Calculate Simple Moving Average

  ## Parameters
    - prices: List of prices, lates price is the first one in the list.
    - period: MA period to be calculated. It must be equal or less than size of prices

  ## Example
  ```
    iex> TAlib.Indicators.MA.sma([1,2,3],3)
    2.0
  ```
  """
  def sma(prices, period \\ 50)
  def sma(_, 0), do: 0
  def sma(prices, period) when is_list(prices) and length(prices) < period, do: 0
  def sma(prices, period) when is_list(prices) do
    slice_index = price_history_slice_index(length(prices), period)
    price_history = Enum.slice(prices, slice_index, period)
    Enum.sum(price_history) / length(price_history)
  end

  @doc """
  Calculate Cumulative Moving Average

  ## Parameters
    - prices: List of prices, lates price is the first one in the list.
    - period: MA period to be calculated. It must be less than size of prices

  ## Example
  ```
    iex> TAlib.Indicators.MA.cma([0,1,2,3],3)
    2.0
  ```
  """
  def cma(prices, period \\ 50)
  def cma(_, 0), do: 0
  def cma(prices, period) when is_list(prices) and length(prices) <= period, do: 0
  def cma(prices, period) when is_list(prices) do
    slice_index = price_history_slice_index(length(prices), period)
    price_history = Enum.slice(prices, slice_index, period)
    Enum.sum(price_history) / length(price_history)
  end

  @doc """
  Calculate Weighted Moving Average

  ## Parameters
    - prices: List of prices, lates price is the first one in the list.
    - period: MA period to be calculated. It must be equal or less than size of prices

  ## Example
  ```
    iex> TAlib.Indicators.MA.wma([0,1,2,3],3)
    2.3333333333333335
  ```
  """
  def wma(prices, period \\ 50)
  def wma(_, 0), do: 0
  def wma(prices, period) when is_list(prices) and length(prices) < period, do: 0
  def wma(prices, period) when is_list(prices) do
    slice_index = price_history_slice_index(length(prices), period)
    price_history = Enum.slice(prices, slice_index, period)
    weighted_total =
      Enum.with_index(price_history)
      |> Enum.reduce(0, fn {val, idx}, acc -> acc + val * (idx + 1) end)
    weighted_total / (period * (period + 1) / 2)
  end

  @doc """
  Calculate Exponential Moving Average

  ## Parameters
    - prices: List of prices, lates price is the first one in the list.
    - period: MA period to be calculated. It must be equal or less than size of prices

  ## Example
  ```
    iex> TAlib.Indicators.MA.ema([0,1,2,3],3)
    1.0
  ```
  """
  def ema(prices, period \\ 50)
  def ema(_, 0), do: 0
  def ema(prices, period) when is_list(prices) and length(prices) < period, do: 0
  def ema(prices, period) when is_list(prices) and length(prices)==period, do: sma(prices, period)
  def ema(prices, period) do
    multiplier = 2/(period+1)
    last_ema = ema(tl(prices), period)
    last_ema + (multiplier * (hd(prices)- last_ema))
  end

  defp price_history_slice_index(priceCount, period) when priceCount <= period, do: 0
  defp price_history_slice_index(priceCount, period), do: priceCount - period
end
