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
    iex> TAlib.Indicators.MA.sma([1,2,3,4],3)
    3.0
  ```
  """
  def sma(prices, period \\ 50)
  def sma(_, 0), do: 0
  def sma(prices, period) when is_list(prices) and length(prices) < period, do: 0
  def sma(prices, period) when is_list(prices) do
    price_history = Enum.slice(prices, 1, period)
    Enum.sum(price_history) / period
  end


  @doc """
  Update Simple Moving Average when new price comes

  ## Parameters
    - prices: List of prices, newest price is the first one in the list.
    - current_sma: Previously calculated SMA
    - new_value: New price to be added in the list
    - period: MA period to be calculated. It must be equal or less than size of prices

  ## Example
  ```
    iex> TAlib.Indicators.MA.update_sma(@prices, 44.6028, 46.0826, 10), 4)
    44.6028
  ```
  """
  def update_sma(prices, current_sma, new_value, period\\50)
  def update_sma(prices, _current_sma, _new_value, period) when is_list(prices) and length(prices)< period+2, do: 0
  def update_sma(prices, current_sma, new_value, period) when is_list(prices) do
    value_to_remove = Enum.at(prices, period + 1)
    current_sma + new_value/period - value_to_remove/period
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
    price_history = Enum.slice(prices, 0, period)
    Enum.sum(price_history) / period
  end

  @doc """
  Update Cumulative Moving Average when new price comes

  ## Parameters
    - current_cma: Previously calculated CMA
    - new_value: New price to be added in the list
    - period: MA period to be calculated.

  ## Example
  ```
    iex> TAlib.Indicators.MA.update_cma(44.4513,44, 4)
    44.36104
  ```
  """
  def update_cma(current_cma, new_value, period) do
    current_cma + ((new_value-current_cma)/(period + 1))
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
    price_history = Enum.slice(prices, 0, period)
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

  @doc """
  Update Exponential Moving Average when new price comes

  ## Parameters
    - current_ema: Previously calculated EMA
    - new_value: New price to be added in the list
    - period: MA period to be calculated.

  ## Example
  ```
    iex> TAlib.Indicators.MA.update_ema(1306.72, 1300, 50), 4)
    1306.456471
  ```
  """
  def update_ema(current_ema, new_value, period) do
    multiplier = 2/(period+1)
    current_ema + (multiplier * (new_value - current_ema))
  end
end
