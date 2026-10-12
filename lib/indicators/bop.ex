defmodule TAlib.Indicators.BOP do
  @moduledoc """
  Balance of Power: `(close - open) / (high - low)`.

  Ranges from -1 (close at the low after opening at the high) to 1. Bars
  are maps with `:open`, `:high`, `:low` and `:close`; zero-range bars
  give `nil`. See `TAlib` for the conventions.
  """

  @doc """
  The Balance of Power of the latest bar.

  ## Examples

      iex> bars = [
      ...>   %{open: 9.5, high: 10, low: 9, close: 9.5},
      ...>   %{open: 10.0, high: 11, low: 9.5, close: 10.5}
      ...> ]
      iex> TAlib.Indicators.BOP.bop(bars) |> Float.round(4)
      0.3333
  """
  @spec bop(list(map)) :: float | nil
  def bop([]), do: nil

  def bop(bars) when is_list(bars), do: List.last(bop_list(bars))

  @doc """
  The Balance of Power of every bar.

      iex> TAlib.Indicators.BOP.bop_list([
      ...>   %{open: 9.5, high: 10, low: 9, close: 9.5},
      ...>   %{open: 10.0, high: 11, low: 9.5, close: 10.5}
      ...> ])
      [0.0, 0.3333333333333333]
  """
  @spec bop_list(list(map)) :: list(float | nil)
  def bop_list(bars) when is_list(bars) do
    Enum.map(bars, fn %{open: open, high: high, low: low, close: close} ->
      range = high - low
      if range == 0, do: nil, else: (close - open) / range
    end)
  end
end
