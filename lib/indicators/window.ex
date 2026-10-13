# Rolling-window extremes in one pass, shared by the windowed
# indicators (stochastic, williams %R, aroon, donchian, midpoint,
# stoch RSI). Two monotonic deques — indices whose values strictly
# decrease (max) or increase (min) — give the window extreme at the
# front in O(1) amortized per bar, instead of re-walking each window.
defmodule TAlib.Indicators.Window do
  @moduledoc false

  @doc false
  # One `{max, min}` per full window, oldest window first; window k
  # covers values `[k - period + 1, k]`. `nil` when there is not
  # enough data.
  @spec maxes_mins(list(number), pos_integer) :: list({number, number}) | nil
  def maxes_mins(values, period) when is_list(values) do
    if length(values) < period do
      nil
    else
      values
      |> walk(period, fn _i, tuple, max_q, min_q ->
        {elem(tuple, :queue.get(max_q)), elem(tuple, :queue.get(min_q))}
      end)
    end
  end

  @doc false
  # One `max` per full window, oldest window first.
  @spec maxes(list(number), pos_integer) :: list(number) | nil
  def maxes(values, period) when is_list(values) do
    if length(values) < period do
      nil
    else
      values |> walk(period, fn _i, tuple, max_q, _min_q -> elem(tuple, :queue.get(max_q)) end)
    end
  end

  @doc false
  # One `min` per full window, oldest window first.
  @spec mins(list(number), pos_integer) :: list(number) | nil
  def mins(values, period) when is_list(values) do
    if length(values) < period do
      nil
    else
      values |> walk(period, fn _i, tuple, _max_q, min_q -> elem(tuple, :queue.get(min_q)) end)
    end
  end

  @doc false
  # One `{max_index, min_index}` (absolute, earliest tie wins) per full
  # window, oldest window first — for Aroon's days-since-extreme.
  @spec extremes(list(number), pos_integer) :: list({non_neg_integer, non_neg_integer}) | nil
  def extremes(values, period) when is_list(values) do
    if length(values) < period do
      nil
    else
      values
      |> walk(period, fn _i, _tuple, max_q, min_q ->
        {:queue.get(max_q), :queue.get(min_q)}
      end)
    end
  end

  # The deques hold indices; equal values never evict each other, so
  # the front is the earliest extreme of the window.
  defp walk(values, period, emit) do
    tuple = List.to_tuple(values)

    {reversed, _max_q, _min_q} =
      Enum.reduce(0..(tuple_size(tuple) - 1)//1, {[], :queue.new(), :queue.new()}, fn i,
                                                                                      {acc, max_q,
                                                                                       min_q} ->
        value = elem(tuple, i)

        max_q = trim(max_q, value, tuple, &</2)
        min_q = trim(min_q, value, tuple, &>/2)

        max_q = :queue.in(i, max_q)
        min_q = :queue.in(i, min_q)

        max_q = expire(max_q, i, period)
        min_q = expire(min_q, i, period)

        if i >= period - 1 do
          {[emit.(i, tuple, max_q, min_q) | acc], max_q, min_q}
        else
          {acc, max_q, min_q}
        end
      end)

    Enum.reverse(reversed)
  end

  # Drop strictly-worse candidates from the rear so the deque stays
  # monotonic; equals stay, keeping the earlier index ahead.
  defp trim(queue, value, tuple, worse) do
    if :queue.is_empty(queue) or not worse.(elem(tuple, :queue.get_r(queue)), value) do
      queue
    else
      queue |> :queue.out_r() |> elem(1) |> trim(value, tuple, worse)
    end
  end

  # Drop the front index once it slides out of the window.
  defp expire(queue, i, period) do
    if :queue.get(queue) <= i - period do
      queue |> :queue.out() |> elem(1)
    else
      queue
    end
  end
end
