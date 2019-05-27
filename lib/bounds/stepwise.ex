defmodule Bounds.Stepwise do
  defstruct [:bounds, :step]

  def new(%Bounds{} = bounds, step) when is_integer(step) and step >= 1 do
    %__MODULE__{bounds: bounds, step: step}
  end
end

defimpl Enumerable, for: Bounds.Stepwise do
  alias Bounds
  alias Bounds.Stepwise

  def count(%Stepwise{bounds: %Bounds{lower: lower, upper: upper}, step: step}) do
    {:ok, div(upper - lower, step)}
  end

  def member?(%Stepwise{bounds: %Bounds{lower: lower, upper: upper}, step: step}, %Bounds{lower: a, upper: b}) do
    {:ok, (a >= lower) and (b <= upper) and ((b - a) == step) and (rem(a - lower, step) == 0) and (rem(b - lower, step) == 0)}
  end

  def reduce(%Stepwise{bounds: %Bounds{lower: lower, upper: upper}, step: step}, acc, fun) do
    reduce(lower, upper, step, acc, fun)
  end

  defp reduce(_lower, _upper, _step, {:halt, acc}, _fun), do:
    {:halted, acc}
  defp reduce(lower, upper, step, {:suspend, acc}, fun), do:
    {:suspended, acc, &reduce(lower, upper, step, &1, fun)}
  defp reduce(lower, upper, step, {:cont, acc}, _fun) when lower + step > upper, do:
    {:done, acc}
  defp reduce(lower, upper, step, {:cont, acc}, fun) when lower + step <= upper do
    next = lower + step
    val = %Bounds{lower: lower, upper: next}
    reduce(next, upper, step, fun.(val, acc), fun)
  end

  def slice(%Stepwise{bounds: %Bounds{lower: lower, upper: upper}, step: step_size}) do
    count = div(upper - lower, step_size)

    slicer = fn offset, len ->
      new_lower = lower + (offset * step_size)
      new_upper = :erlang.min(new_lower + (len * step_size), upper)
      slicer_accum(new_lower, new_upper, step_size, [])
    end

    {:ok, count, slicer}
  end

  defp slicer_accum(lower, upper, step_size, acc) do
    prev = upper - step_size

    if prev < lower do
      acc
    else
      val = %Bounds{lower: prev, upper: upper}
      slicer_accum(lower, prev, step_size, [val | acc])
    end
  end
end
