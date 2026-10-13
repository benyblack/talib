defmodule TAlib.Indicators.TRIX do
  alias TAlib.Indicators.MA

  @moduledoc """
  TRIX [Wikipedia](https://en.wikipedia.org/wiki/TRIX).

  A triple-smoothed EMA rate of change: the percent change of an EMA
  applied three times over. Values are close to zero in flat trends; the
  signal is usually its own EMA (not provided here).

  See `TAlib` for the input conventions: prices are always given in
  chronological order, oldest first, and the series is returned aligned
  with the input. `nil` is returned when there is not enough data.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate the latest TRIX value, in percent.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: EMA period, a positive integer (default 14).

  At least `3 * (period - 1) + 2` prices are required for the triple EMA
  to have two defined values to compare; otherwise `nil` is returned.

  ## Examples

      iex> TAlib.Indicators.TRIX.trix([1, 2, 3, 4, 5, 6, 7, 8], 2) |> Float.round(4)
      18.1818
  """
  @spec trix(list(number), pos_integer) :: float | nil
  def trix(prices, period \\ 14)

  def trix(_prices, period) when not is_valid_period(period), do: TAlib.invalid_period!(period)

  def trix(prices, period)
      when is_list(prices) and length(prices) < 3 * (period - 1) + 2,
      do: nil

  def trix(prices, period) when is_list(prices), do: List.last(trix_series(prices, period))

  @doc """
  Calculate the full TRIX series.

  Returns a list aligned with `prices`: the first `3 * (period - 1) + 1`
  entries are `nil`, and every later entry is the one-bar percent change
  of the triple EMA.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: EMA period, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.TRIX.trix_list([1, 2, 3, 4, 5, 6, 7, 8], 2) |> Enum.map(fn
      ...>   nil -> nil
      ...>   x -> Float.round(x, 4)
      ...> end)
      [nil, nil, nil, nil, 40.0, 28.5714, 22.2222, 18.1818]
  """
  @spec trix_list(list(number), pos_integer) :: list(float | nil)
  def trix_list(prices, period \\ 14)

  def trix_list(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def trix_list(prices, period) when is_list(prices) do
    values = trix_series(prices, period)
    List.duplicate(nil, length(prices) - length(values)) ++ values
  end

  defp trix_series(prices, period) do
    triple_ema =
      prices
      |> MA.ema_list(period)
      |> Enum.reject(&is_nil/1)
      |> MA.ema_list(period)
      |> Enum.reject(&is_nil/1)
      |> MA.ema_list(period)
      |> Enum.reject(&is_nil/1)

    triple_ema |> percent_changes([])
  end

  defp percent_changes([], acc), do: Enum.reverse(acc)
  defp percent_changes([_single], acc), do: Enum.reverse(acc)

  defp percent_changes([prev, current | rest], acc),
    do: percent_changes([current | rest], [(current / prev - 1) * 100 | acc])
end
