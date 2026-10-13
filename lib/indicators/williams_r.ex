defmodule TAlib.Indicators.WilliamsR do
  alias TAlib.Indicators.Window

  @moduledoc """
  Williams %R [Wikipedia](https://en.wikipedia.org/wiki/Williams_%25R).

  `%R = (Highest High - Close) / (Highest High - Lowest Low) * -100`

  Ranges from -100 (close at the window low) to 0 (close at the window
  high). See `TAlib` for the input conventions: prices are always given in
  chronological order, oldest first, and the series is returned aligned
  with the input. `nil` is returned when there is not enough data or the
  window has no range (flat prices), since %R is then undefined.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate the latest Williams %R.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.WilliamsR.williams_r([5, 9, 3, 8, 2, 6], 3) |> Float.round(4)
      -33.3333
  """
  @spec williams_r(list(number), pos_integer) :: float | nil
  def williams_r(prices, period \\ 14)

  def williams_r(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def williams_r(prices, period) when is_list(prices) and length(prices) < period, do: nil

  def williams_r(prices, period) when is_list(prices) do
    window = Enum.take(prices, -period)
    highest = Enum.max(window)
    lowest = Enum.min(window)

    if highest == lowest do
      nil
    else
      (highest - List.last(window)) / (highest - lowest) * -100
    end
  end

  @doc """
  Calculate the full Williams %R series.

  Returns a list aligned with `prices`: the first `period - 1` entries are
  `nil`, and every later entry is %R of the window ending at that point.
  Windows with no range produce `nil`.

  ## Parameters

    - prices: list of prices, oldest first.
    - period: lookback window, a positive integer (default 14).

  ## Examples

      iex> TAlib.Indicators.WilliamsR.williams_r_list([5, 9, 3, 8, 2, 6], 3) |> Enum.map(fn
      ...>   nil -> nil
      ...>   x -> Float.round(x, 4)
      ...> end)
      [nil, nil, -100.0, -16.6667, -100.0, -33.3333]
  """
  @spec williams_r_list(list(number), pos_integer) :: list(float | nil)
  def williams_r_list(prices, period \\ 14)

  def williams_r_list(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def williams_r_list(prices, period) when is_list(prices) and length(prices) < period,
    do: List.duplicate(nil, length(prices))

  def williams_r_list(prices, period) when is_list(prices) do
    values =
      prices
      |> Window.maxes_mins(period)
      |> Enum.zip(Enum.drop(prices, period - 1))
      |> Enum.map(fn
        {{highest, lowest}, close} when highest != lowest ->
          (highest - close) / (highest - lowest) * -100

        _ ->
          nil
      end)

    List.duplicate(nil, period - 1) ++ values
  end
end
