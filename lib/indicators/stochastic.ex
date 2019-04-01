defmodule TAlib.Indicators.Stochastic do
  alias TAlib.Indicators.MA

  @moduledoc """
  Stochastic Oscillator [Wikipedia](https://en.wikipedia.org/wiki/Stochastic_oscillator)
  - %K = (Current Close - Lowest Low)/(Highest High - Lowest Low) * 100
  - %D = 3-day SMA of %K

  - Lowest Low = lowest low for the look-back period
  - Highest High = highest high for the look-back period
  - %K is multiplied by 100 to move the decimal point two places
  """

  @doc """
  %K = (Current Close - Lowest Low)/(Highest High - Lowest Low) * 100

  ## Parameters
  - prices: List of prices, lates price is the first one in the list.
  - period: MA period to be calculated. Default value is 14

  ## Example
  ```
  iex> prices = [1330.95, 1334.65, 1340, 1338.7, ...]
  iex> TAlib.Indicators.Stochastic.stochastic_k(prices)
  90.51859612362499
  ```
  """
  def stochastic_k(prices, period \\ 14)
  def stochastic_k(prices, period) when is_list(prices) and length(prices) < period, do: 0
  def stochastic_k(prices, period) when is_list(prices) do
    price_history = Enum.slice(prices, 0, period)
    lowest_low = Enum.min(price_history)
    (hd(price_history) - lowest_low)/(Enum.max(price_history) - lowest_low) * 100
  end

    @doc """
  %D = 3-day SMA of %K

  ## Parameters
  - prices: List of prices, lates price is the first one in the list.
  - period: MA period to be calculated. Default value is 14

  ## Example
  ```
  iex> prices = [1330.95, 1334.65, 1340, 1338.7, ...]
  iex> TAlib.Indicators.Stochastic.stochastic_k(prices)
  90.51859612362499
  ```
  """
  def stochastic_d(prices, period \\ 3, k_period \\ 14)
  def stochastic_d(prices, period, _k_period) when is_list(prices) and length(prices) < period, do: 0
  def stochastic_d(prices, period, k_period) when is_list(prices) do
    counter = 0..period
    k_list =  Enum.map(counter, fn(x) ->
      stochastic_k(Enum.slice(prices, x, k_period))
    end)
    MA.sma(k_list, 3)
  end

end
