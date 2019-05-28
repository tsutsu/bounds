defmodule Bounds.ExtendedEnumerable do
  defstruct [:most, :extra]
end

defimpl Enumerable, for: Bounds.ExtendedEnumerable do
  alias Bounds
  alias Bounds.ExtendedEnumerable, as: EE

  def count(%EE{most: l}) when is_list(l), do:
    {:ok, length(l) + 1}

  def count(%EE{most: most}) do
    case Enumerable.count(most) do
      {:ok, n} -> {:ok, n + 1}
      {:error, _} = err -> err
    end
  end

  def member?(%EE{most: most, extra: extra}, el) do
    if extra == el do
      {:ok, true}
    else
      Enumerable.member?(most, el)
    end
  end

  def reduce(%EE{most: most, extra: extra}, acc0, fun) do
    case Enumerable.reduce(most, acc0, fun) do
      {:halted, _} = halt_info ->
        halt_info
      {:suspended, _, _} = susp_info ->
        susp_info
      {:done, acc1} ->
        reduce_final(fun.(extra, acc1), fun)
    end
  end

  defp reduce_final({:halt, acc}, _fun), do:
    {:halted, acc}
  defp reduce_final({:suspend, acc}, fun), do:
    {:suspended, acc, &reduce_final(&1, fun)}
  defp reduce_final({:cont, acc}, _fun), do:
    {:done, acc}

  def slice(%EE{most: most, extra: extra}) do
    case Enumerable.slice(most) do
      {:ok, most_size, most_slicer} ->
        full_size = most_size + 1

        full_slicer = fn
          (^most_size, 1) ->
            [extra]

          (offset, len) when (offset + len) == full_size ->
            most_slicer.(offset, len - 1) ++ [extra]

          (offset, len) when (offset + len) < full_size ->
            most_slicer.(offset, len)
        end

        {:ok, full_size, full_slicer}

      {:error, _} = err ->
        err
    end
  end
end
