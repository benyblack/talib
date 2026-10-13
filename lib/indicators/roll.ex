# O(1) stepping primitives for the streaming (`init`/`next`) APIs: a
# rolling window sum and monotonic-deque rolling extremes. The fill and
# slide arithmetic deliberately matches the batch sliding walks
# operation for operation — the fill accumulates `sum + v` left to
# right exactly like `Enum.sum` over the first window, and the slide is
# the batch walks' `sum - leaving + adding` — so a state stepped through
# a history continues the corresponding batch series bit for bit.
defmodule TAlib.Indicators.Roll do
  @moduledoc false

  defmodule Sum do
    @moduledoc false
    @type t :: %__MODULE__{}
    defstruct [:period, :sum, :queue, :filled]
  end

  defmodule Max do
    @moduledoc false
    @type t :: %__MODULE__{}
    defstruct [:period, :tick, :queue]
  end

  defmodule Min do
    @moduledoc false
    @type t :: %__MODULE__{}
    defstruct [:period, :tick, :queue]
  end

  @doc false
  @spec sum_new(pos_integer) :: Sum.t()
  def sum_new(period), do: %Sum{period: period, sum: 0, queue: :queue.new(), filled: false}

  @doc false
  # Run `history` through a streaming step, collecting the emitted
  # series alongside the final state — the shared body of `*_init`.
  @spec replay(list, term, (term, term -> {term, term})) :: {term, list(term)}
  def replay(history, state, step) do
    {state, reversed} =
      Enum.reduce(history, {state, []}, fn item, {state, acc} ->
        {state, value} = step.(state, item)
        {state, [value | acc]}
      end)

    {state, Enum.reverse(reversed)}
  end

  @doc false
  # Push a value: `{state, window_sum | nil}` — `nil` until the window
  # has filled, the full-window sum once it has, the sliding sum after.
  @spec sum_push(Sum.t(), number) :: {Sum.t(), number | nil}
  def sum_push(%Sum{period: period, sum: sum, queue: q, filled: false} = state, value) do
    q2 = :queue.in(value, q)
    sum2 = sum + value

    if :queue.len(q2) == period do
      {%{state | sum: sum2, queue: q2, filled: true}, sum2}
    else
      {%{state | sum: sum2, queue: q2}, nil}
    end
  end

  def sum_push(%Sum{sum: sum, queue: q} = state, value) do
    leaving = :queue.get(q)
    sum2 = sum - leaving + value
    q2 = q |> :queue.out() |> elem(1) |> then(&:queue.in(value, &1))
    {%{state | sum: sum2, queue: q2}, sum2}
  end

  @doc false
  @spec max_new(pos_integer) :: Max.t()
  def max_new(period), do: %Max{period: period, tick: -1, queue: :queue.new()}

  @doc false
  @spec min_new(pos_integer) :: Min.t()
  def min_new(period), do: %Min{period: period, tick: -1, queue: :queue.new()}

  @doc false
  # Push a value onto the max deque: `{state, {tick, value} | nil}` —
  # `nil` until `period` values have been seen, the window maximum
  # (with its absolute tick, earliest tie winning) once it has.
  @spec max_push(Max.t(), number) :: {Max.t(), {non_neg_integer, number} | nil}
  def max_push(%Max{period: period, tick: tick, queue: q} = state, value) do
    tick2 = tick + 1
    q2 = q |> trim_max(value) |> then(&:queue.in({tick2, value}, &1)) |> expire(tick2 - period)

    if tick2 >= period - 1 do
      {%{state | tick: tick2, queue: q2}, :queue.get(q2)}
    else
      {%{state | tick: tick2, queue: q2}, nil}
    end
  end

  @doc false
  @spec min_push(Min.t(), number) :: {Min.t(), {non_neg_integer, number} | nil}
  def min_push(%Min{period: period, tick: tick, queue: q} = state, value) do
    tick2 = tick + 1
    q2 = q |> trim_min(value) |> then(&:queue.in({tick2, value}, &1)) |> expire(tick2 - period)

    if tick2 >= period - 1 do
      {%{state | tick: tick2, queue: q2}, :queue.get(q2)}
    else
      {%{state | tick: tick2, queue: q2}, nil}
    end
  end

  # Evict strictly-worse candidates from the rear (equals stay, so the
  # earliest tie keeps the front), insert the new candidate at the
  # rear, then drop the front once it leaves the window — the same
  # deque evolution as the batch `Window` walk.
  defp trim_max(q, value) do
    if :queue.is_empty(q) or elem(:queue.get_r(q), 1) >= value do
      q
    else
      q |> :queue.out_r() |> elem(1) |> trim_max(value)
    end
  end

  defp trim_min(q, value) do
    if :queue.is_empty(q) or elem(:queue.get_r(q), 1) <= value do
      q
    else
      q |> :queue.out_r() |> elem(1) |> trim_min(value)
    end
  end

  defp expire(q, limit) do
    if :queue.is_empty(q) or elem(:queue.get(q), 0) > limit do
      q
    else
      q |> :queue.out() |> elem(1)
    end
  end
end
