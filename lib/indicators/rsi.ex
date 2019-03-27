defmodule TAlib.Indicators.RSI do
  @moduledoc """
  RSI indicator https://en.wikipedia.org/wiki/Relative_strength_index
  Calculate RSI based on price history
  """

  def calculateRSI(prices, period \\ 14)
  def calculateRSI([], _), do: 0
  def calculateRSI(prices, period) when is_list(prices) and length(prices) < period, do: 0

  def calculateRSI(prices, period) when is_list(prices) do
    sliceIndex = priceHistorySliceIndex(length(prices), period)
    priceHistory = Enum.slice(prices, sliceIndex, period)
    rs = averageGain(priceHistory) / averageLoss(priceHistory)
    100 - 100 / (1 + rs)
  end

  def averageGain(prices, period \\ 14)
  def averageGain([], _), do: 0
  def averageGain(prices, period) when is_list(prices) do
    sliceIndex = priceHistorySliceIndex(length(prices), period)
    priceHistory = Enum.slice(prices, sliceIndex, period)
    totalGaines = gain(priceHistory)
    totalGaines / Enum.count(priceHistory)
  end

  def averageLoss(prices, period \\ 14)
  def averageLoss([], _), do: 0
  def averageLoss(prices, period) when is_list(prices) do
    sliceIndex = priceHistorySliceIndex(length(prices), period)
    priceHistory = Enum.slice(prices, sliceIndex, period)
    totalLosses = loss(priceHistory)
    totalLosses / length(priceHistory)
  end

  defp loss([]), do: 0
  defp loss([_]), do: 0
  defp loss([head | tail]) when hd(tail) >= head, do: loss(tail)
  defp loss([head | tail]) when hd(tail) < head, do: head - hd(tail) + loss(tail)

  defp gain([]), do: 0
  defp gain([_]), do: 0
  defp gain([head | tail]) when hd(tail) <= head, do: gain(tail)
  defp gain([head | tail]) when hd(tail) > head, do: hd(tail) - head + gain(tail)

  defp priceHistorySliceIndex(priceCount, period) when priceCount<=period, do: 0
  defp priceHistorySliceIndex(priceCount, period), do: priceCount - period

end
