defmodule TAlib.Indicators.PriceTransform do
  @moduledoc """
  Price Transform functions (TA-Lib group).

  Bars are maps with at least `:high`, `:low` and `:close` (`:open` for
  `avgprice/1`); extra keys are ignored. Transforms are per-bar and
  defined for every bar. See `TAlib` for the conventions.
  """

  @doc """
  Average Price: `(open + high + low + close) / 4`.

  ## Examples

      iex> TAlib.Indicators.PriceTransform.avgprice(%{open: 10, high: 12, low: 8, close: 11})
      10.25
  """
  @spec avgprice(map) :: float
  def avgprice(%{open: open, high: high, low: low, close: close}),
    do: (open + high + low + close) / 4

  @doc """
  Median Price: `(high + low) / 2`.

  ## Examples

      iex> TAlib.Indicators.PriceTransform.medprice(%{high: 12, low: 8})
      10.0
  """
  @spec medprice(map) :: float
  def medprice(%{high: high, low: low}), do: (high + low) / 2

  @doc """
  Typical Price: `(high + low + close) / 3`.

  ## Examples

      iex> TAlib.Indicators.PriceTransform.typprice(%{high: 12, low: 8, close: 11})
      10.333333333333334
  """
  @spec typprice(map) :: float
  def typprice(%{high: high, low: low, close: close}), do: (high + low + close) / 3

  @doc """
  Weighted Close Price: `(high + low + 2 * close) / 4`.

  ## Examples

      iex> TAlib.Indicators.PriceTransform.wclprice(%{high: 12, low: 8, close: 11})
      10.5
  """
  @spec wclprice(map) :: float
  def wclprice(%{high: high, low: low, close: close}), do: (high + low + 2 * close) / 4

  @doc """
  The Typical Price of every bar.

      iex> TAlib.Indicators.PriceTransform.typprice_list([
      ...>   %{high: 12, low: 8, close: 10},
      ...>   %{high: 13, low: 9, close: 12}
      ...> ])
      [10.0, 11.333333333333334]
  """
  @spec typprice_list(list(map)) :: list(float)
  def typprice_list(bars) when is_list(bars), do: Enum.map(bars, &typprice/1)

  @doc """
  The Median Price of every bar.
  """
  @spec medprice_list(list(map)) :: list(float)
  def medprice_list(bars) when is_list(bars), do: Enum.map(bars, &medprice/1)

  @doc """
  The Weighted Close Price of every bar.
  """
  @spec wclprice_list(list(map)) :: list(float)
  def wclprice_list(bars) when is_list(bars), do: Enum.map(bars, &wclprice/1)

  @doc """
  The Average Price of every bar.
  """
  @spec avgprice_list(list(map)) :: list(float)
  def avgprice_list(bars) when is_list(bars), do: Enum.map(bars, &avgprice/1)
end
