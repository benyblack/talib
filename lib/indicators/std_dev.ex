defmodule TAlib.Indicators.StdDev do
  @moduledoc """
  Rolling population standard deviation.

  See `TAlib` for the input conventions: prices are always given in
  chronological order, oldest first, and the series is returned aligned
  with the input. `nil` is returned when there is not enough data.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate the population standard deviation of the `period` newest
  prices (two-pass formula, dividing by `period`).

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer.

  ## Examples

      iex> TAlib.Indicators.StdDev.std_dev([1, 2, 3, 4], 4) |> Float.round(6)
      1.118034

      iex> TAlib.Indicators.StdDev.std_dev([2, 4, 6, 8], 2)
      1.0
  """
  @spec std_dev(list(number), pos_integer) :: float | nil
  def std_dev(prices, period \\ 50)

  def std_dev(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def std_dev(prices, period) when is_list(prices) and length(prices) < period, do: nil

  def std_dev(prices, period) when is_list(prices) do
    window = Enum.take(prices, -period)
    mean = Enum.sum(window) / period
    total = Enum.reduce(window, 0, fn price, acc -> acc + (price - mean) * (price - mean) end)
    :math.sqrt(total / period)
  end

  @doc """
  Calculate the full rolling standard deviation series in a single pass
  (sliding window sum and sum of squares).

  Returns a list aligned with `prices`: the first `period - 1` entries are
  `nil`, and every later entry is the population standard deviation of the
  window ending at that point.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer.

  ## Examples

      iex> TAlib.Indicators.StdDev.std_dev_list([2, 4, 6, 8], 2)
      [nil, 1.0, 1.0, 1.0]
  """
  @spec std_dev_list(list(number), pos_integer) :: list(float | nil)
  def std_dev_list(prices, period \\ 50)

  def std_dev_list(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def std_dev_list(prices, period) when is_list(prices) and length(prices) < period,
    do: List.duplicate(nil, length(prices))

  def std_dev_list(prices, period) when is_list(prices) do
    window = Enum.take(prices, period)
    initial_sum = Enum.sum(window)
    initial_sq_sum = Enum.reduce(window, 0, fn price, acc -> acc + price * price end)
    ahead = Enum.drop(prices, period)

    List.duplicate(nil, period - 1) ++
      [
        pop_std_dev(initial_sum, initial_sq_sum, period)
        | slide_std_dev(prices, ahead, initial_sum, initial_sq_sum, period, [])
      ]
  end

  defp pop_std_dev(sum, sq_sum, period) do
    variance = max(sq_sum - sum * sum / period, 0)
    :math.sqrt(variance / period)
  end

  defp slide_std_dev(_older, [], _sum, _sq_sum, _period, acc), do: Enum.reverse(acc)

  defp slide_std_dev([leaving | older], [adding | ahead], sum, sq_sum, period, acc) do
    new_sum = sum - leaving + adding
    new_sq_sum = sq_sum - leaving * leaving + adding * adding

    slide_std_dev(older, ahead, new_sum, new_sq_sum, period, [
      pop_std_dev(new_sum, new_sq_sum, period) | acc
    ])
  end
end
