defmodule TAlib.Indicators.RSI do

  @moduledoc """
  RSI indicator https://en.wikipedia.org/wiki/Relative_strength_index
  Calculate RSI based on price history
  """


def calculateRSI([]), do: 0
def calculateRSI(prices) when is_list(prices) do
  rs = averageGain(prices) / averageLoss(prices)
  100-100/(1 + rs)
end

def averageGain([]), do: 0
def averageGain(prices) when is_list(prices) do
  totalGaines = gain(prices)
  totalGaines / Enum.count(prices)
end

def averageLoss([]), do: 0
def averageLoss(prices) when is_list(prices) do
  totalLosses = loss(prices)
  totalLosses / length(prices)
end

defp loss([_]), do: 0
defp loss([head|tail]) when hd(tail) >= head, do: loss(tail)
defp loss([head|tail]) when hd(tail) < head, do: head - hd(tail) + loss(tail)

defp gain([_]), do: 0
defp gain([head|tail]) when hd(tail) <= head, do: gain(tail)
defp gain([head|tail]) when hd(tail) > head,  do: hd(tail) - head + gain(tail)

end
