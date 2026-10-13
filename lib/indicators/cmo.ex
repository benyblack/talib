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
    changes = changes(prices)
    {window, rest} = Enum.split(changes, period)

    gains = Enum.sum(Enum.map(window, &max(&1, 0)))
    losses = Enum.sum(Enum.map(window, &max(-&1, 0)))

    {reversed, _, _, _} =
      Enum.reduce(rest, {[cmo_value(gains, losses) | []], gains, losses, changes}, fn change,
                                                                                      {acc, gains,
                                                                                       losses,
                                                                                       [
                                                                                         leaving
                                                                                         | older
                                                                                       ]} ->
        gains = gains - max(leaving, 0) + max(change, 0)
        losses = losses - max(-leaving, 0) + max(-change, 0)
        {[cmo_value(gains, losses) | acc], gains, losses, older}
      end)

    List.duplicate(nil, period) ++ Enum.reverse(reversed)
  end

  defp changes([first | rest]), do: walk_changes(rest, first, [])
  defp walk_changes([], _prev, acc), do: Enum.reverse(acc)
  defp walk_changes([b | rest], a, acc), do: walk_changes(rest, b, [b - a | acc])

  defp cmo_value(gains, losses) when gains == 0 and losses == 0, do: nil
  defp cmo_value(gains, losses), do: 100 * (gains - losses) / (gains + losses)
end
