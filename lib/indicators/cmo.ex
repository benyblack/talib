defmodule TAlib.Indicators.CMO do
  @moduledoc """
  Chande Momentum Oscillator:
  `100 * (sum of gains - sum of losses) / (sum of gains + sum of losses)`
  over the lookback window.

  See `TAlib` for the conventions: prices are always given in
  chronological order, oldest first, and the series is returned aligned
  with the input. `nil` is returned when there is not enough data or the
  window has no movement.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate the latest Chande Momentum Oscillator value.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.CMO.cmo([1, 2, 3, 4, 3, 5], 2) |> Float.round(4)
      33.3333
  """
  @spec cmo(list(number), pos_integer) :: float | nil
  def cmo(prices, period \\ 14)

  def cmo(_prices, period) when not is_valid_period(period), do: TAlib.invalid_period!(period)

  def cmo(prices, period) when is_list(prices) and length(prices) <= period, do: nil

  def cmo(prices, period) when is_list(prices), do: List.last(cmo_series(prices, period))

  @doc """
  Calculate the full CMO series.

  Returns a list aligned with `prices`: the first `period` entries are
  `nil`, and every later entry is the oscillator of the window ending at
  that point.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.CMO.cmo_list([1, 2, 3, 4, 3, 5], 2) |> Enum.map(fn
      ...>   nil -> nil
      ...>   x -> Float.round(x, 4)
      ...> end)
      [nil, nil, 100.0, 100.0, 0.0, 33.3333]
  """
  @spec cmo_list(list(number), pos_integer) :: list(float | nil)
  def cmo_list(prices, period \\ 14)

  def cmo_list(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def cmo_list(prices, period) when is_list(prices) and length(prices) <= period,
    do: List.duplicate(nil, length(prices))

  def cmo_list(prices, period) when is_list(prices), do: cmo_series(prices, period)

  defp cmo_series(prices, period) do
    changes =
      prices
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [a, b] -> b - a end)

    windows = changes |> Enum.chunk_every(period, 1, :discard)

    values =
      Enum.map(windows, fn window ->
        gains = Enum.sum(Enum.map(window, &max(&1, 0)))
        losses = Enum.sum(Enum.map(window, &max(-&1, 0)))

        cond do
          gains == 0 and losses == 0 -> nil
          true -> 100 * (gains - losses) / (gains + losses)
        end
      end)

    List.duplicate(nil, period) ++ values
  end
end
