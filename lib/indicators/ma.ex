defmodule TAlib.Indicators.MA do
  @moduledoc """
  Moving Average indicator https://en.wikipedia.org/wiki/Moving_average
  Calculate SMA and EMA
  """

  def sma(prices, period \\ 50)
  def sma(_, 0), do: 0
  def sma(prices, period) when is_list(prices) and length(prices) <= period, do: 0

  def sma(prices, period) when is_list(prices) do
    slice_index = price_historyslice_index(length(prices), period)
    price_history = Enum.slice(prices, slice_index - 1, period)
    Enum.sum(price_history) / length(price_history)
  end

  def cma(prices, period \\ 50)
  def cma(_, 0), do: 0
  def cma(prices, period) when is_list(prices) and length(prices) <= period, do: 0
  def cma(prices, period) when is_list(prices) do
    slice_index = price_historyslice_index(length(prices), period)
    price_history = Enum.slice(prices, slice_index, period)
    Enum.sum(price_history) / length(price_history)
  end

  def wma(prices, period \\ 50)
  def wma(_, 0), do: 0
  def wma(prices, period) when is_list(prices) and length(prices) <= period, do: 0
  def wma(prices, period) when is_list(prices) do
    slice_index = price_historyslice_index(length(prices), period)
    price_history = Enum.slice(prices, slice_index, period)

    weighted_total =
      Enum.with_index(price_history)
      |> Enum.reduce(0, fn {val, idx}, acc -> acc + val * (idx + 1) end)

    weighted_total / (period * (period + 1) / 2)
  end

  defp price_historyslice_index(priceCount, period) when priceCount <= period, do: 0
  defp price_historyslice_index(priceCount, period), do: priceCount - period
end
