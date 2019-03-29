defmodule TAlib.Indicators.RSI do
  @moduledoc """
  RSI indicator https://en.wikipedia.org/wiki/Relative_strength_index
  Calculate RSI based on price history
  """

  def rsi(prices, period \\ 14)
  def rsi([], _), do: 0
  def rsi(prices, period) when is_list(prices) and length(prices) < period, do: 0
  def rsi(prices, period) when is_list(prices) do
    slice_index = price_history_slice_index(length(prices), period)
    price_history = Enum.slice(prices, slice_index, period)
    rs = average_gain(price_history) / average_loss(price_history)
    100 - 100 / (1 + rs)
  end

  def average_gain(prices, period \\ 14)
  def average_gain([], _), do: 0
  def average_gain(prices, period) when is_list(prices) do
    slice_index = price_history_slice_index(length(prices), period)
    price_history = Enum.slice(prices, slice_index, period)
    totalGaines = gain(price_history)
    totalGaines / Enum.count(price_history)
  end

  def average_loss(prices, period \\ 14)
  def average_loss([], _), do: 0
  def average_loss(prices, period) when is_list(prices) do
    slice_index = price_history_slice_index(length(prices), period)
    price_history = Enum.slice(prices, slice_index, period)
    totalLosses = loss(price_history)
    totalLosses / length(price_history)
  end

  defp loss([]), do: 0
  defp loss([_]), do: 0
  defp loss([head | tail]) when hd(tail) >= head, do: loss(tail)
  defp loss([head | tail]) when hd(tail) < head, do: head - hd(tail) + loss(tail)

  defp gain([]), do: 0
  defp gain([_]), do: 0
  defp gain([head | tail]) when hd(tail) <= head, do: gain(tail)
  defp gain([head | tail]) when hd(tail) > head, do: hd(tail) - head + gain(tail)

  defp price_history_slice_index(priceCount, period) when priceCount<=period, do: 0
  defp price_history_slice_index(priceCount, period), do: priceCount - period

end
