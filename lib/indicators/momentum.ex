defmodule TAlib.Indicators.Momentum do
  @moduledoc """
  Momentum [Wikipedia](https://en.wikipedia.org/wiki/Momentum_(technical_analysis)).

  `MOM = price - price_period_bars_ago`

  See `TAlib` for the input conventions: prices are always given in
  chronological order, oldest first, and the series is returned aligned
  with the input. `nil` is returned when there is not enough data.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate the latest Momentum.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: how many bars back to compare against, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.Momentum.momentum([1, 2, 4, 8], 2)
      6
  """
  @spec momentum(list(number), pos_integer) :: number | nil
  def momentum(prices, period \\ 14)

  def momentum(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def momentum(prices, period) when is_list(prices) and length(prices) <= period, do: nil

  def momentum(prices, period) when is_list(prices),
    do: List.last(prices) - Enum.at(prices, length(prices) - period - 1)

  @doc """
  Calculate the full Momentum series in a single pass.

  Returns a list aligned with `prices`: the first `period` entries are
  `nil`, and every later entry is the price change over `period` bars.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: how many bars back to compare against, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.Momentum.momentum_list([1, 2, 4, 8], 2)
      [nil, nil, 3, 6]
  """
  @spec momentum_list(list(number), pos_integer) :: list(number | nil)
  def momentum_list(prices, period \\ 14)

  def momentum_list(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def momentum_list(prices, period) when is_list(prices) do
    nils = List.duplicate(nil, min(period, length(prices)))

    current = Enum.drop(prices, period)
    lagged = Enum.take(prices, length(prices) - period)

    nils ++ do_momentum(current, lagged, [])
  end

  defp do_momentum([], [], acc), do: Enum.reverse(acc)

  defp do_momentum([current | current_rest], [base | base_rest], acc) do
    do_momentum(current_rest, base_rest, [current - base | acc])
  end
end
