defmodule TAlib.Indicators.RSI do
  @moduledoc """
  RSI indicator [Wikipedia](https://en.wikipedia.org/wiki/Relative_strength_index)
  Calculate RSI based on price history
  """

  @doc """
  Calculate RSI for a list of items

  ## Parameters
    - data: List of prices
    - period: Period of calculation. Default is 14.
    - top_is_first: This one show if the list is ascending or descending based on dates. Regularly for OHLC data it needs to be false, because the older data comes first.

  ## Example
  ```
    iex> data = [1,2,3 ... ,100]
    iex> TAlib.Indicators.RSI.rsi_list(data)
    [nil, nil, nil ... ,100,100,100]
  ```
  """
  @spec rsi_list(list, number, bool) :: list
  def rsi_list(data, period \\ 14, top_is_first \\ false)
  def rsi_list(data, period, false), do: Enum.reverse(rsi_list(Enum.reverse(data), period, true))
  def rsi_list(data, period, true) when length(data) == 1, do: [rsi(data, period)]
  def rsi_list(data, period, true) do
    rsi_of_head = rsi(data, period)
    [rsi_of_head] ++ rsi_list(tl(data), period, true)
  end

  @doc """
  RSI calculation

  ## Parameters
    - prices: List of prices, lates price is the first one in the list.
    - period: Period of calculation. Default is 14.

  ## Example
  ```
    iex> prices = [1330.95, 1334.65, 1340, 1338.7, ...]
    iex> TAlib.Indicators.RSI.rsi(prices)
    19.052001840773087
  ```
  """
  def rsi(prices, period \\ 14)
  def rsi([], _), do: 0
  def rsi(prices, period) when is_list(prices) and length(prices) <= period, do: nil
  def rsi(prices, period) when is_list(prices) do
    do_rs = fn
      (_, 0.0) -> -1
      (gain, loss) -> gain / loss
    end
    do_rsi = fn
      (-1) -> 100
      (rs) -> (100 - (100 / (1 + rs)))
    end
    rs = do_rs.(average_gain(prices, period), average_loss(prices, period))
    do_rsi.(rs)
  end

  @doc """
  Sum of Gains over the past x periods

  ## Parameters
    - prices: List of prices, lates price is the first one in the list.
    - period: Period of calculation. Default is 14.

  ## Example
  ```
    iex> prices = [1330.95, 1334.65, 1340, 1338.7, ...]
    iex> TAlib.Indicators.RSI.average_gain(prices)
    2.9571428571428475
  ```
  """
  def average_gain(prices, period \\ 14)
  def average_gain([], _), do: 0
  def average_gain(prices, period) when is_list(prices) do
    price_history = Enum.slice(prices, 0, period+1)
    totalGaines = gain(price_history)
    totalGaines / (length(price_history)-1)
  end

  @doc """
  Sum of Losses over the past x periods

  ## Parameters
    - prices: List of prices, lates price is the first one in the list.
    - period: Period of calculation. Default is 14.

  ## Example
  ```
    iex> prices = [1330.95, 1334.65, 1340, 1338.7, ...]
    iex> TAlib.Indicators.RSI.average_loss(prices)
    12.564285714285704
  ```
  """
  def average_loss(prices, period \\ 14)
  def average_loss([], _), do: 0
  def average_loss(prices, period) when is_list(prices) do
    price_history = Enum.slice(prices, 0, period+1)
    totalLosses = loss(price_history)
    totalLosses / (length(price_history)-1)
  end

  def gain([]), do: 0
  def gain([_]), do: 0
  def gain([head | tail]) when hd(tail) >= head, do: gain(tail)
  def gain([head | tail]) when hd(tail) < head do
    head - hd(tail) + gain(tail)
  end

  def loss([]), do: 0
  def loss([_]), do: 0
  def loss([head | tail]) when hd(tail) <= head, do: loss(tail)
  def loss([head | tail]) when hd(tail) > head do
    hd(tail) - head + loss(tail)
  end

end
