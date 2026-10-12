defmodule TAlib.Indicators.Stats do
  @moduledoc """
  Statistic functions (TA-Lib group).

  Linear regression fits `y = intercept + slope * x` over each lookback
  window with `x = 0..period - 1`. `linear_reg/2` is the fitted value at
  the window's last point, `tsf/2` projects one bar ahead, `angle/2` is
  the slope in degrees. `beta/3` and `correl/3` relate two series over
  the window. See `TAlib` for the conventions: chronological input,
  series aligned with the input, `nil` for insufficient data.
  """

  defguardp is_valid_period(period) when is_integer(period) and period >= 1

  @doc """
  The population Variance of the `period` newest prices.

      iex> TAlib.Indicators.Stats.variance([1, 2, 3, 4], 2)
      0.25
  """
  @spec variance(list(number), pos_integer) :: float | nil
  def variance(prices, period \\ 14)

  def variance(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def variance(prices, period) when is_list(prices) and length(prices) < period, do: nil

  def variance(prices, period) when is_list(prices) do
    mean = Enum.sum(Enum.take(prices, -period)) / period

    Enum.reduce(Enum.take(prices, -period), 0, fn price, acc ->
      acc + (price - mean) * (price - mean)
    end) / period
  end

  @doc """
  Beta of `prices` against `market` over the `period` newest points:
  `covariance / market variance`.

      iex> TAlib.Indicators.Stats.beta([1, 2, 3, 4], [2, 4, 6, 8], 3)
      2.0
  """
  @spec beta(list(number), list(number), pos_integer) :: float | nil
  def beta(prices, market, period \\ 14)

  def beta(_prices, _market, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def beta(prices, market, period) when is_list(prices) and is_list(market) do
    case moments(prices, market, period) do
      {cov, var_x, _var_y} -> if var_x == 0, do: nil, else: cov / var_x
      nil -> nil
    end
  end

  @doc """
  Pearson correlation of the two series over the `period` newest points.

      iex> TAlib.Indicators.Stats.correl([1, 2, 3, 4], [2, 4, 6, 8], 3)
      1.0
  """
  @spec correl(list(number), list(number), pos_integer) :: float | nil
  def correl(prices, market, period \\ 14)

  def correl(_prices, _market, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def correl(prices, market, period) when is_list(prices) and is_list(market) do
    case moments(prices, market, period) do
      {cov, var_x, var_y} ->
        denominator = :math.sqrt(var_x * var_y)
        if denominator == 0, do: nil, else: cov / denominator

      nil ->
        nil
    end
  end

  @doc """
  The fitted value of the linear regression at the window's last point
  (TA-Lib LINEARREG).

      iex> TAlib.Indicators.Stats.linear_reg([1, 2, 3, 4, 5], 3)
      5.0
  """
  @spec linear_reg(list(number), pos_integer) :: float | nil
  def linear_reg(prices, period \\ 14)

  def linear_reg(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def linear_reg(prices, period) when is_list(prices) and length(prices) < period, do: nil

  def linear_reg(prices, period) when is_list(prices) do
    {slope, intercept} = fit(Enum.take(prices, -period))
    intercept + slope * (period - 1)
  end

  @doc """
  The slope of the linear regression over the `period` newest prices
  (TA-Lib LINEARREG_SLOPE).

      iex> TAlib.Indicators.Stats.slope([1, 2, 3, 4, 5], 3)
      1.0
  """
  @spec slope(list(number), pos_integer) :: float | nil
  def slope(prices, period \\ 14)

  def slope(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def slope(prices, period) when is_list(prices) and length(prices) < period, do: nil

  def slope(prices, period) when is_list(prices),
    do: prices |> Enum.take(-period) |> fit() |> elem(0)

  @doc """
  The intercept of the linear regression over the `period` newest prices
  (TA-Lib LINEARREG_INTERCEPT).

      iex> TAlib.Indicators.Stats.intercept([1, 2, 3, 4, 5], 3)
      3.0
  """
  @spec intercept(list(number), pos_integer) :: float | nil
  def intercept(prices, period \\ 14)

  def intercept(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def intercept(prices, period) when is_list(prices) and length(prices) < period, do: nil

  def intercept(prices, period) when is_list(prices),
    do: prices |> Enum.take(-period) |> fit() |> elem(1)

  @doc """
  The regression slope in degrees
  (TA-Lib LINEARREG_ANGLE).

      iex> TAlib.Indicators.Stats.angle([1, 2, 3, 4, 5], 3)
      45.0
  """
  @spec angle(list(number), pos_integer) :: float | nil
  def angle(prices, period \\ 14)

  def angle(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def angle(prices, period) when is_list(prices) and length(prices) < period, do: nil

  def angle(prices, period) when is_list(prices) do
    prices |> Enum.take(-period) |> fit() |> elem(0) |> :math.atan() |> Kernel.*(180 / :math.pi())
  end

  @doc """
  The Time Series Forecast: the regression projected one bar past the
  window's last point (TA-Lib TSF).

      iex> TAlib.Indicators.Stats.tsf([1, 2, 3, 4, 5], 3)
      6.0
  """
  @spec tsf(list(number), pos_integer) :: float | nil
  def tsf(prices, period \\ 14)

  def tsf(_prices, period) when not is_valid_period(period),
    do: TAlib.invalid_period!(period)

  def tsf(prices, period) when is_list(prices) and length(prices) < period, do: nil

  def tsf(prices, period) when is_list(prices) do
    {slope, intercept} = fit(Enum.take(prices, -period))
    intercept + slope * period
  end

  # Least squares over a window with x = 0..n-1.
  defp fit(window) do
    n = length(window)
    sum_x = div(n * (n - 1), 2)
    sum_x2 = div((n - 1) * n * (2 * n - 1), 6)
    sum_y = Enum.sum(window)
    {sum_xy, _} = Enum.reduce(window, {0, 0}, fn y, {acc, x} -> {acc + x * y, x + 1} end)

    denominator = n * sum_x2 - sum_x * sum_x
    slope = (n * sum_xy - sum_x * sum_y) / denominator
    intercept = (sum_y - slope * sum_x) / n
    {slope, intercept}
  end

  # Covariance and variances of the two windows (population moments).
  defp moments(prices, market, period) do
    x = Enum.take(prices, -period)
    y = Enum.take(market, -period)

    if length(x) == period and length(y) == period do
      mean_x = Enum.sum(x) / period
      mean_y = Enum.sum(y) / period

      {cov, var_x, var_y} =
        Enum.zip(x, y)
        |> Enum.reduce({0, 0, 0}, fn {a, b}, {c, vx, vy} ->
          {c + (a - mean_x) * (b - mean_y), vx + (a - mean_x) * (a - mean_x),
           vy + (b - mean_y) * (b - mean_y)}
        end)

      {cov / period, var_x / period, var_y / period}
    end
  end
end
