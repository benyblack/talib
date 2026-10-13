defmodule TAlib.Indicators.StochRSI do
  alias TAlib.Indicators.Window
  alias TAlib.Indicators.RSI

  @moduledoc """
  Stochastic RSI: the fast stochastic of the RSI series.

  `%K = (RSI - lowest RSI) / (highest RSI - lowest RSI) * 100` over the
  stochastic window. See `TAlib` for the conventions: prices are always
  given in chronological order, oldest first, and the series is returned
  aligned with the input. `nil` is returned when there is not enough
  data or the RSI window has no range.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  Calculate the latest Stochastic RSI (fast %K).

  ## Parameters

    - prices: list of prices, oldest first.
    - rsi_period: RSI lookback window, a positive integer (default 14).
    - stoch_period: stochastic window over the RSI series (default 5).

  ## Examples

      iex> TAlib.Indicators.StochRSI.stoch_rsi([3, 5, 2, 6, 1, 4, 5, 3, 6, 2], 3, 3)
      0.0
  """
  @spec stoch_rsi(list(number), pos_integer, pos_integer) :: float | nil
  def stoch_rsi(prices, rsi_period \\ 14, stoch_period \\ 5)

  def stoch_rsi(_prices, rsi_period, _stoch_period) when not is_valid_period(rsi_period),
    do: TAlib.invalid_period!(rsi_period)

  def stoch_rsi(_prices, _rsi_period, stoch_period) when not is_valid_period(stoch_period),
    do: TAlib.invalid_period!(stoch_period)

  def stoch_rsi(prices, rsi_period, stoch_period)
      when is_list(prices) and length(prices) < rsi_period + stoch_period,
      do: nil

  def stoch_rsi(prices, rsi_period, stoch_period) when is_list(prices),
    do: List.last(stoch_rsi_series(prices, rsi_period, stoch_period))

  @doc """
  Calculate the full Stochastic RSI series, defined from index
  `rsi_period + stoch_period - 1` on.

  ## Parameters

    - prices: list of prices, oldest first.
    - rsi_period: RSI lookback window, a positive integer (default 14).
    - stoch_period: stochastic window over the RSI series (default 5).

  ## Examples

      iex> TAlib.Indicators.StochRSI.stoch_rsi_list([3, 5, 2, 6, 1, 4, 5, 3, 6, 2], 3, 3) |> Enum.map(fn
      ...>   nil -> nil
      ...>   x -> Float.round(x, 4)
      ...> end)
      [nil, nil, nil, nil, nil, 60.9677, 100.0, 0.0, 100.0, 0.0]
  """
  @spec stoch_rsi_list(list(number), pos_integer, pos_integer) :: list(float | nil)
  def stoch_rsi_list(prices, rsi_period \\ 14, stoch_period \\ 5)

  def stoch_rsi_list(_prices, rsi_period, _stoch_period) when not is_valid_period(rsi_period),
    do: TAlib.invalid_period!(rsi_period)

  def stoch_rsi_list(_prices, _rsi_period, stoch_period) when not is_valid_period(stoch_period),
    do: TAlib.invalid_period!(stoch_period)

  def stoch_rsi_list(prices, rsi_period, stoch_period) when is_list(prices),
    do: stoch_rsi_series(prices, rsi_period, stoch_period)

  defp stoch_rsi_series(prices, rsi_period, stoch_period) do
    rsis = prices |> RSI.rsi_list(rsi_period) |> Enum.reject(&is_nil/1)
    {values, _} = walk_stoch(rsis, stoch_period)

    List.duplicate(nil, length(prices) - length(values)) ++ values
  end

  defp walk_stoch(rsis, stoch_period) do
    case Window.maxes_mins(rsis, stoch_period) do
      nil ->
        {[], nil}

      mms ->
        values =
          mms
          |> Enum.zip(Enum.drop(rsis, stoch_period - 1))
          |> Enum.map(fn
            {{highest, lowest}, last} when highest != lowest ->
              (last - lowest) / (highest - lowest) * 100

            _ ->
              nil
          end)

        {values, nil}
    end
  end
end
