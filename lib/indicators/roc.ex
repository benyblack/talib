defmodule TAlib.Indicators.ROC do
  @moduledoc """
  Rate of Change [Wikipedia](https://en.wikipedia.org/wiki/Momentum_(technical_analysis)).

  `ROC = (price / price_period_bars_ago - 1) * 100`

  See `TAlib` for the input conventions: prices are always given in
  chronological order, oldest first, and the series is returned aligned
  with the input. `nil` is returned when there is not enough data. Prices
  must be non-zero for the division to be defined.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate the latest Rate of Change, in percent.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: how many bars back to compare against, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.ROC.roc([1, 2, 4, 8], 2)
      300.0
  """
  @spec roc(list(number), pos_integer) :: float | nil
  def roc(prices, period \\ 14)

  def roc(_prices, period) when not is_valid_period(period), do: TAlib.invalid_period!(period)

  def roc(prices, period) when is_list(prices) and length(prices) <= period, do: nil

  def roc(prices, period) when is_list(prices) do
    base = Enum.at(prices, length(prices) - period - 1)
    (List.last(prices) / base - 1) * 100
  end

  @doc """
  Calculate the full Rate of Change series in a single pass.

  Returns a list aligned with `prices`: the first `period` entries are
  `nil`, and every later entry is the rate of change over `period` bars.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: how many bars back to compare against, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.ROC.roc_list([1, 2, 4, 8], 2)
      [nil, nil, 300.0, 300.0]
  """
  @spec roc_list(list(number), pos_integer) :: list(float | nil)
  def roc_list(prices, period \\ 14)

  def roc_list(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def roc_list(prices, period) when is_list(prices) do
    nils = List.duplicate(nil, min(period, length(prices)))

    current = Enum.drop(prices, period)
    lagged = Enum.take(prices, length(prices) - period)

    nils ++ do_roc(current, lagged, [])
  end

  defp do_roc([], [], acc), do: Enum.reverse(acc)

  defp do_roc([current | current_rest], [base | base_rest], acc) do
    do_roc(current_rest, base_rest, [(current / base - 1) * 100 | acc])
  end
end
