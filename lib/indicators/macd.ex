defmodule TAlib.Indicators.MACD do
  alias TAlib.Indicators.MA

  def macd(prices, fast \\ 12, slow \\ 26)
  def macd(prices, _fast, slow) when is_list(prices) and length(prices)<(slow*2), do: 0
  def macd(prices, fast, slow) when is_list(prices) do
    MA.ema(prices, fast) - MA.ema(prices, slow)
  end


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

  def histogram(prices, macd_fast \\ 12, macd_slow \\ 26, signal_period \\ 9)
  def histogram(prices, _macd_fast, macd_slow, _signal_period) when is_list(prices) and length(prices) < (macd_slow*2), do: 0
  def histogram(prices, _macd_fast, _macd_slow, signal_period) when is_list(prices) and length(prices) < (signal_period*2-1), do: 0
  def histogram(prices, macd_fast, macd_slow, signal_period) when is_list(prices) do
    macd(prices, macd_fast, macd_slow) - signal(prices, signal_period)
  end

end
