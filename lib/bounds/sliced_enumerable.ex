defmodule Bounds.SlicedEnumerable do
  defstruct [
    enum: [],
    initial_size: 0,
    bounds: %Bounds{}
  ]

  @doc false
  def base(enum, size \\ nil) do
    enum_initial_size = case {Enumerable.slice(enum), size} do
      {{:ok, count_from_enum, _}, _} ->
        count_from_enum
      {{:error, _}, nil} ->
        raise ArgumentError, "an explicit size must be provided when Enumerable.count(value) is not O(1)"
      {{:error, _}, :infinity} ->
        :infinity
      {{:error, _}, explicit_size} when is_integer(explicit_size) and explicit_size >= 0 ->
        explicit_size
    end

    %__MODULE__{enum: enum, initial_size: enum_initial_size, bounds: %Bounds{upper: enum_initial_size}}
  end

  def slice(%__MODULE__{bounds: bounds} = slice, slicing_bounds) do
    %__MODULE__{slice | bounds: Bounds.slice(bounds, slicing_bounds)}
  end

  def unslice(%__MODULE__{initial_size: enum_initial_size} = slice) do
    %__MODULE__{slice | bounds: %Bounds{upper: enum_initial_size}}
  end

  def to_list(%__MODULE__{enum: enum, bounds: %Bounds{lower: lower, upper: upper}}) do
    Enum.slice(enum, lower, upper - lower)
  end
end

defimpl Bounds.Sliced, for: Bounds.SlicedEnumerable do
  alias Bounds.SlicedEnumerable

  def bounds(%SlicedEnumerable{bounds: bounds}), do:
    bounds

  def slice(%SlicedEnumerable{} = sliced_value, slicing_bounds), do:
    SlicedEnumerable.slice(sliced_value, slicing_bounds)

  def unslice(%SlicedEnumerable{} = sliced_value), do:
    SlicedEnumerable.unslice(sliced_value)

  def value(%SlicedEnumerable{} = sliced_value), do:
    SlicedEnumerable.to_list(sliced_value)
end

defimpl Bounds.Sliced, for: List do
  alias Bounds.SlicedEnumerable

  def bounds(l) when is_list(l), do:
    %Bounds{upper: length(l)}

  def slice(l, slicing_bounds) when is_list(l), do:
    SlicedEnumerable.slice(SlicedEnumerable.base(l, length(l)), slicing_bounds)

  def unslice(l) when is_list(l), do:
    SlicedEnumerable.base(l, length(l))

  def value(l) when is_list(l), do:
    l
end

defimpl Bounds.Sliced, for: Stream do
  alias Bounds.SlicedEnumerable

  def bounds(%Stream{}), do:
    %Bounds{upper: :infinity}

  def slice(%Stream{} = s, slicing_bounds), do:
    SlicedEnumerable.slice(SlicedEnumerable.base(s, :infinity), slicing_bounds)

  def unslice(%Stream{} = s), do:
    SlicedEnumerable.base(s, :infinity)

  def value(%Stream{} = s), do:
    Enum.to_list(s)
end

defimpl Bounds.Sliced, for: Range do
  alias Bounds.SlicedEnumerable

  def bounds(%Range{} = r), do:
    %Bounds{upper: Enum.count(r)}

  def slice(%Range{} = r, slicing_bounds), do:
    SlicedEnumerable.slice(SlicedEnumerable.base(r), slicing_bounds)

  def unslice(%Range{} = r), do:
    SlicedEnumerable.base(r)

  def value(%Range{} = r), do:
    Enum.to_list(r)
end

defimpl Inspect, for: Bounds.SlicedEnumerable do
  import Inspect.Algebra
  alias Bounds.SlicedEnumerable

  def inspect(%SlicedEnumerable{} = slice, opts) do
    list = SlicedEnumerable.to_list(slice)

    concat([
      color("|", :binary, opts),
      to_doc(list, opts),
      color("|", :binary, opts)
    ])
  end
end

defimpl Enumerable, for: Bounds.SlicedEnumerable do
  alias Bounds.SlicedEnumerable

  def count(%SlicedEnumerable{bounds: %Bounds{upper: :infinity}}), do:
    {:error, __MODULE__}
  def count(%SlicedEnumerable{bounds: %Bounds{lower: lower, upper: upper}}), do:
    {:ok, upper - lower}

  def member?(%SlicedEnumerable{}, _), do:
    {:error, __MODULE__}

  def reduce(%SlicedEnumerable{enum: list, bounds: %Bounds{lower: lower, upper: upper}}, acc, fun) when is_list(list) do
    {_, list} = :lists.split(lower, list)
    reduce_list(list, upper - lower, acc, fun)
  end
  def reduce(%SlicedEnumerable{enum: enum, bounds: %Bounds{lower: lower, upper: upper}}, acc, fun) do
    s = case lower do
      0 -> enum
      n when n > 0 -> Stream.drop(enum, n)
    end

    s = case upper do
      :infinity -> s
      n when is_integer(n) and n > 0 -> Stream.take(s, n - lower)
    end

    Enumerable.Stream.reduce(s, acc, fun)
  end

  defp reduce_list(_list, _take, {:halt, acc}, _fun), do:
    {:halted, acc}
  defp reduce_list(list, take, {:suspend, acc}, fun), do:
    {:suspended, acc, &reduce_list(list, take, &1, fun)}
  defp reduce_list([], _, {:cont, acc}, _fun), do:
    {:done, acc}
  defp reduce_list(_, 0, {:cont, acc}, _fun), do:
    {:done, acc}
  defp reduce_list([head | list], take, {:cont, acc}, fun) when take > 0, do:
    reduce_list(list, take - 1, fun.(head, acc), fun)

  def slice(%SlicedEnumerable{}), do:
    {:error, __MODULE__}
end
