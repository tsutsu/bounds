defmodule Bounds do
  @moduledoc ~S"""
  `Bounds` is a formalization of the `{pos, len}` tuple that is used in Erlang to slice binaries.

  A Bounds value is similar to a `Range` value, with a few differences:

  * A Bounds value can be zero-length. (A Range value must represent at least one element.)

  * A Bounds value is always ascending. (A Range value may be descending.)

  * A Bounds value always has non-negative values. (A Range value may represent negative values.)

  Bounds values may therefore represent single points, equivalent to `{pos, 0}` tuples.

  ## Implementation

  Bounds values are normalized as an interval `[lower, upper]` for convenience of calculation. All functions
  in the `Bounds` module expect a `%Bounds{}` to have been created by a call to a constructor function (e.g.
  `new/2`, `from_poslen/1`, `from_range/1`.) If you construct a Bounds value yourself, the following guard must hold:

  ```
  %Bounds{lower: lower, upper: upper} when
    is_integer(lower) and is_integer(upper) and lower >= 0 and upper >= lower
  ```

  ## Enumeration

  Like `Range`, `Bounds` implements `Enumerable`; and thus, like Range values, Bounds values can be
  understood as a compact representation of an equivalent list value.

  Unlike `Range`, `Bounds` has several decorators which implement `Enumerable` differently, to
  represent the different, equivalent abstractions that a Bounds value can be understood as.

  A Bounds value, passed directly to `Enum` functions, will enumerate as a collection of all
  integer points in the closed interval `[lower, upper]`. If your algorithm wants "point" Bounds
  values (values where `lower == upper`) to be included as values in the enumeration, then this is the
  approach you want.

  A common use-case is enumerating all half-closed intervals of some length `n` (e.g. `[lower, lower + n)`)
  which are contained by a given Bounds value. For example, if the Bounds value represents the bounds of a binary,
  then you might want the bounds of each byte of the binary: `[0, 1)`, `[1, 2)`, etc. The functions `stepwise/2`,
  `split_stepwise/2`, and `partitioned/3` will help with this.
  """

  defstruct [
    lower: 0,
    upper: 0
  ]


  @doc "Constructs a new Bounds value from a position and a length."
  def new(pos, len), do: from_poslen({pos, len})


  @doc "Casts a compatible value to a Bounds value."
  def new(poslen_or_range)
  def new({pos, len}), do: from_poslen({pos, len})
  def new(%Range{} = r), do: from_range(r)


  @doc "Converts a `{pos, len}` tuple to an equivalent Bounds value."
  def from_poslen(poslen)
  def from_poslen({pos, len}) when is_integer(pos) and is_integer(len) and pos >= 0 and len >= 0, do:
    %__MODULE__{lower: pos, upper: pos + len}


  @doc "Converts a Bounds value to an equivalent `{pos, len}` tuple."
  def to_poslen(%__MODULE__{lower: lower, upper: upper}), do:
    {lower, upper - lower}


  @doc "Creates a zero-length Bounds value centered on the integer `point`."
  def at_point(point) when is_integer(point) and point >= 0, do:
    %__MODULE__{lower: point, upper: point}


  @doc "Determines whether a Bounds value is zero-length."
  def point?(%__MODULE__{lower: point, upper: point}), do: true
  def point?(%__MODULE__{lower: lower, upper: upper}) when lower < upper, do: false


  @doc ~S"""
  Returns the integer point that a given Bounds value represents.

  Raises an exception if the given Bounds value does not represent a point.
  """
  def to_point!(%__MODULE__{lower: point, upper: point}), do: point
  def to_point!(%__MODULE__{lower: lower, upper: upper} = bounds) when lower < upper, do:
    raise ArgumentError, "cannot convert #{inspect bounds} to point"


  @doc ~S"""
  Filters the passed `Map` or `Enumerable` value for only the Bounds values
  which are zero-length (i.e. points.)
  """
  def points(m) when is_map(m), do:
    Map.new(Enum.filter(m, fn {_, bounds} -> point?(bounds) end))
  def points(enum), do:
    Enum.filter(enum, &point?/1)


  @doc "Converts a `Range` to an equivalent Bounds value."
  def from_range(first..last) when is_integer(first) and is_integer(last) and first >= 0 and last >= first, do:
    %__MODULE__{lower: first, upper: last + 1}


  @doc "Determines whether a Bounds value is a valid `Range` (i.e. has nonzero size.)"
  def range?(%__MODULE__{lower: point, upper: point}), do: false
  def range?(%__MODULE__{lower: lower, upper: upper}) when lower < upper, do: true


  @doc ~S"""
  Returns the `Range` of integer points that a given Bounds value represents.

  Raises an exception if the given Bounds value does not represent a range of points (i.e.
  because it instead represents a single point.)
  """
  def to_range(%__MODULE__{lower: point, upper: point} = bounds), do:
    raise ArgumentError, "cannot convert #{inspect bounds} to Range"
  def to_range(%__MODULE__{lower: lower, upper: upper}) when lower < upper, do:
    {lower, upper - 1}


  @doc ~S"""
  Filters the passed `Map` or `Enumerable` value for only the Bounds values
  which are valid `Range`s (i.e. which are of nonzero length.)
  """
  def ranges(m) when is_map(m), do:
    Map.new(Enum.filter(m, fn {_, bounds} -> range?(bounds) end))
  def ranges(enum), do:
    Enum.filter(enum, &range?/1)


  @doc ~S"""
  Constructs a Bounds value representing the bounds of the given binary `bin`, i.e. the
  interval:

  ```
  [0, byte_size(bin))
  ```
  """
  def from_binary(bin) when is_binary(bin), do:
    %__MODULE__{upper: byte_size(bin)}


  @doc ~S"""
  Returns the size of the Bounds value when interpreted as a half-closed interval `[lower, upper)`.
  """
  def size(%__MODULE__{lower: lower, upper: upper}), do: upper - lower


  @doc ~S"""
  Returns a `Bounds.Stepwise` decorator value, which implements `Enumerable`.

  The values enumerated from a `Bounds.Stepwise` decorator are themselves Bounds values,
  representing a set of contiguous intervals, each of size `step_size`. The enumeration always begins
  with the interval `[0, step_size)` (if it exists.)

  Any bounded interval smaller than `step_size` is not considered a part of the enumeration.

  This enumeration strategy is useful when you have a sequence of unit-sized chunks (like the bytes
  in a binary), in which a representation for one element is encoded as `step_size` contiguous chunks.
  The enumerated values will then represent the bounds of the representations of all
  potentially-valid elements.

  ## Examples

  Get the bounds of each single byte of a binary:

      iex> Bounds.from_binary("foo") |> Bounds.stepwise(1) |> Enum.to_list()
      [%Bounds{lower: 0, upper: 1}, %Bounds{lower: 1, upper: 2}, %Bounds{lower: 2, upper: 3}]

  Get the bounds of a sequence of 32-bit values in a binary:
      iex> Bounds.from_binary("abcdEFGH") |> Bounds.stepwise(4) |> Enum.to_list()
      [%Bounds{lower: 0, upper: 4}, %Bounds{lower: 4, upper: 8}]
  """
  def stepwise(%__MODULE__{} = bounds, step_size \\ 1) when is_integer(step_size) and step_size >= 1 do
    %Bounds.Stepwise{bounds: bounds, step: step_size}
  end


  @doc ~S"""
  Splits a Bounds value into three parts, returned as a map with the following keys:

  * `:whole`: the bounds of the contiguous set of values whose bounds are both 1. within the original bounds,
    and 2. divisible by `step_size`. This is equivalent to the `union/2` of the `stepwise/2`
    enumeration of the given `bounds` at the given `step_size`.
  * `:partial_before`: the interval extending from the beginning of the original bounds, to the
    beginning of `whole`.
  * `:partial_after`: the interval extending from the end of `whole`, to the end of the original bounds.

  Any/all of the values in this map may turn out to be zero-sized "point" Bounds.
  """
  def split_stepwise(%__MODULE__{lower: lower, upper: upper} = bounds, 1), do: %{
    partial_before: %Bounds{lower: lower, upper: lower},
    whole: bounds,
    partial_after: %Bounds{lower: upper, upper: upper}
  }
  def split_stepwise(%__MODULE__{lower: lower, upper: upper}, step) when is_integer(step) and step >= 2 do
    whole_lower = case rem(lower, step) do
      0 -> lower
      n when n > 0 -> lower - n + step
    end
    whole_upper = upper - rem(upper, step)
    %{
      partial_before: %Bounds{lower: lower, upper: whole_lower},
      whole: %Bounds{lower: whole_lower, upper: whole_upper},
      partial_after: %Bounds{lower: whole_upper, upper: upper},
    }
  end


  @doc ~S"""
  Returns a `Bounds.Partitioned` decorator value, which implements `Enumerable`.

  The values enumerated from a `Bounds.Partitioned` decorator will be Bounds values representing
  a set of contiguous intervals. Most of these will be steps of size `step`. The first full interval
  (if it exists) will be `[offset, offset + step)`.

  Unlike with `intervals/2`, the values enumerated from a `Bounds.Partitioned` value will include intervals
  smaller than `step`—namely:

  * if `offset` is nonzero, an *initial* interval `[0, offset)` will appear at the beginning of the
    enumeration (if it exists.)

  * if, after removing the *initial* interval, `step` does not evenly divide the bounds, then a
    *final* interval `[step * n, step * n + remainder)` will appear at the end of the enumeration (if it
    exists.)

  This enumeration strategy is useful when you are using Bounds to compactly represent a set of
  values, and you wish to "bin" these values into contiguous bins of size `step`.
  """
  def partitioned(%__MODULE__{} = _bounds, step, offset) when is_integer(step) and step >= 1 and is_integer(offset) and offset < step do
    throw :not_implemented
    # full_part = stepwise(translate(bounds, offset))
    # %Bounds.Partitioned{bounds: bounds, step: step}
  end


  @doc ~S"""
  Returns the end points (i.e. the points on either end) of the closed interval represented
  by the Bounds value.

  If the Bounds value represents a point, there will be one end point returned (the same point.)
  Otherwise, there will be two points returned.
  """
  def endpoints(%__MODULE__{lower: point, upper: point} = bounds), do:
    [bounds]
  def endpoints(%__MODULE__{lower: lower, upper: upper}) when lower < upper, do:
    [%__MODULE__{lower: lower, upper: lower}, %__MODULE__{lower: upper, upper: upper}]


  @doc ~S"""
  Returns a new Bounds value representing the result of translating (sliding) the endpoints of
  `bounds` up or down by the integer displacement `disp`.
  """
  def translate(bounds, disp)
  def translate(%__MODULE__{lower: lower, upper: upper}, disp) when is_integer(disp) do
    %__MODULE__{lower: lower + disp, upper: upper + disp}
  end


  @doc ~S"""
  Takes a sub-interval of `bounds` as a new Bounds value.

  `slicing_bounds` does not represent an absolute interval to intersect with `bounds`,
  but rather is taken as a relative offset and length, as in `Enum.slice/3`.

  This operation can be understood as having equivalent semantics to that of `Enum.slice/3`. The
  offset and length will be "clamped" so that the result will be fully contained by `bounds`.
  """
  def slice(bounds, slicing_bounds)
  def slice(%__MODULE__{lower: lower, upper: upper}, %__MODULE__{lower: a, upper: b}) do
    new_lower = :erlang.min(lower + a, upper)
    new_upper = :erlang.min(lower + b, upper)
    %__MODULE__{lower: new_lower, upper: new_upper}
  end
  def slice(%__MODULE__{} = bounds, other), do:
    slice(bounds, Bounds.new(other))


  @doc ~S"""
  Creates a new Bounds value by limiting the lower and upper bounds of `value_bounds` to be no more than
  the lower and upper bounds of `clamp_bounds`.

  If `value_bounds` fully contains `clamp_bounds`, the result of the clamp will be `clamp_bounds` exactly.
  """
  def clamp(value_bounds, clamp_bounds)
  def clamp(%__MODULE__{lower: lower, upper: upper}, %__MODULE__{lower: clamp_lower, upper: clamp_upper}) do
    new_lower = :erlang.min(:erlang.max(lower, clamp_lower), clamp_upper)
    new_upper = :erlang.min(:erlang.max(upper, clamp_lower), clamp_upper)
    %__MODULE__{lower: new_lower, upper: new_upper}
  end


  @doc ~S"""
  Removes the open interval `sub_bounds` from the closed interval `bounds` and returns whatever is
  left over.

  If `sub_bounds` has one or both endpoints in common with `bounds`, point (zero-length)
  bounds will be left over at the shared endpoint.

  ## Examples

  Subtracting from the middle produces two interval-bounds:

      iex> Bounds.difference(%Bounds{lower: 0, upper: 10}, %Bounds{lower: 3, upper: 6})
      [%Bounds{lower: 0, upper: 3}, %Bounds{lower: 6, upper: 10}]

  Subtracting from one end produces one point-bound and one interval-bound:

      iex> Bounds.difference(%Bounds{lower: 0, upper: 10}, %Bounds{lower: 0, upper: 2})
      [%Bounds{lower: 0, upper: 0}, %Bounds{lower: 2, upper: 10}]

  Subtracting everything produces two point-bounds:

      iex> Bounds.difference(%Bounds{lower: 0, upper: 10}, %Bounds{lower: 0, upper: 10})
      [%Bounds{lower: 0, upper: 0}, %Bounds{lower: 10, upper: 10}]

  Subtracting from a point always produces the same point:

      iex> Bounds.difference(%Bounds{lower: 5, upper: 5}, %Bounds{lower: 0, upper: 10})
      [%Bounds{lower: 5, upper: 5}]
  """
  def difference(%__MODULE__{lower: lower, upper: upper} = bounds, %__MODULE__{} = sub_bounds) do
    %__MODULE__{lower: a, upper: b} = clamp(sub_bounds, bounds)
    uniq_pair(%__MODULE__{lower: lower, upper: a}, %__MODULE__{lower: b, upper: upper})
  end

  @doc ~S"""
  Returns two sub-intervals representing the result of "breaking" `bounds` at a given position.

  The second argument `point_or_idx_or_offset` can take a few forms, each with a different result:

  * If it is an integer ≥ 0, it will be used to calculate a point to break relative to `bounds.lower`;
  * If it is an integer < 0, it will be used to calculate a point to break relative to `bounds.upper`;
  * If it is a Bounds value and `Bounds.point?(bounds)` is true, it will be used as an absolute point to
    break at.

  ## Examples

  Non-negative relative offsets:

      iex> Bounds.split_at(%Bounds{lower: 5, upper: 10}, 1)
      [%Bounds{lower: 5, upper: 6}, %Bounds{lower: 6, upper: 10}]

  Negative relative offsets:

      iex> Bounds.split_at(%Bounds{lower: 5, upper: 10}, -1)
      [%Bounds{lower: 5, upper: 9}, %Bounds{lower: 9, upper: 10}]

  Absolute break positions:

      iex> Bounds.split_at(%Bounds{lower: 5, upper: 10}, %Bounds{lower: 7, upper: 7})
      [%Bounds{lower: 5, upper: 7}, %Bounds{lower: 7, upper: 10}]

  If the interval is broken at one of its endpoints, one of the resulting sub-intervals will be a point bound:

      iex> Bounds.split_at(%Bounds{lower: 0, upper: 10}, 0)
      [%Bounds{lower: 0, upper: 0}, %Bounds{lower: 0, upper: 10}]
  """
  def split_at(bounds, point_or_idx_or_offset)
  def split_at(%__MODULE__{lower: lower, upper: upper} = bounds, %__MODULE__{lower: point, upper: point}) when point >= lower and point <= upper, do:
    split_at(bounds, point - lower)
  def split_at(%__MODULE__{lower: lower, upper: upper} = bounds, offset) when is_integer(offset) and offset < 0 and (lower - upper) <= offset, do:
    split_at(bounds, (upper - lower) + offset)
  def split_at(%__MODULE__{lower: lower, upper: upper}, at_idx) when is_integer(at_idx) and at_idx >= 0 and at_idx <= (upper - lower), do:
    uniq_pair(%__MODULE__{lower: lower, upper: lower + at_idx}, %__MODULE__{lower: lower + at_idx, upper: upper})


  # def partition(@empty = b, _at_idxs), do: b
  # def partition(%__MODULE__{record: {_, _}} = b0, at_idxs) do
  #   Enum.reduce(at_idxs, [b0], fn at_idx, [last_bound | bounds_acc] ->
  #     case split(last_bound, at_idx) do
  #       {^last_bound} -> [last_bound | bounds_acc]
  #       {split_before, split_after} -> [split_after | [split_before | bounds_acc]]
  #     end
  #   end)
  #   |> Enum.reverse()
  # end


  def concat(%Bounds{} = bounds_a, %Bounds{} = bounds_b), do:
    concat_all(order_pair(bounds_a, bounds_b))
  def concat(bounds_enum), do:
    concat_all(Enum.sort(bounds_enum))

  defp concat_all(sorted_bounds_enum) do
    Enum.reduce(sorted_bounds_enum, fn
      %__MODULE__{lower: common, upper: upper}, %__MODULE__{lower: lower, upper: common} ->
        %Bounds{lower: lower, upper: upper}
      bounds_new, bounds_acc ->
        raise Bounds.DisjointError, {bounds_acc, bounds_new}
    end)
  end


  @compile inline: [uniq_pair: 2, order_pair: 2]
  defp uniq_pair(a, a), do: [a]
  defp uniq_pair(a, b), do: [a, b]

  defp order_pair(a, b) when a > b, do: [b, a]
  defp order_pair(a, b), do: [a, b]
end

defimpl Inspect, for: Bounds do
  import Inspect.Algebra

  def inspect(%Bounds{lower: point, upper: point}, opts) do
    concat([
      color("@", :tuple, opts),
      color(to_string(point), :number, opts)
      # color(")", :tuple, opts)
    ])
  end

  def inspect(%Bounds{lower: lower, upper: upper}, opts) when lower < upper do
    concat([
      # color("(", :tuple, opts),
      color(to_string(lower), :number, opts),
      color("...", :tuple, opts),
      color(to_string(upper), :number, opts)
      # color(")", :tuple, opts)
    ])
  end
end

defimpl Enumerable, for: Bounds do
  def count(%Bounds{lower: lower, upper: upper}), do:
    {:ok, (upper - lower) + 1}

  def member?(%Bounds{lower: lower, upper: upper}, %Bounds{lower: point, upper: point}) when point >= lower and point <= upper, do: {:ok, true}
  def member?(%Bounds{}, _), do: {:ok, false}

  def reduce(%Bounds{lower: lower, upper: upper}, acc, fun), do:
    reduce(lower, (upper - lower) + 1, acc, fun)

  defp reduce(_n, _take, {:halt, acc}, _fun), do:
    {:halted, acc}
  defp reduce(n, take, {:suspend, acc}, fun), do:
    {:suspended, acc, &reduce(n, take, &1, fun)}
  defp reduce(_, 0, {:cont, acc}, _fun), do:
    {:done, acc}
  defp reduce(n, take, {:cont, acc}, fun) when take > 0, do:
    reduce(n + 1, take - 1, fun.(%Bounds{lower: n, upper: n}, acc), fun)


  def slice(%Bounds{lower: lower, upper: upper}) do
    count = (upper - lower) + 1

    slicer = fn offset, len ->
      new_lower = lower + offset
      new_upper = :erlang.min(new_lower + len, upper)
      slicer_accum(new_lower, new_upper, [])
    end

    {:ok, count, slicer}
  end

  defp slicer_accum(lower, upper, acc) when lower > upper, do: acc
  defp slicer_accum(lower, upper, acc) when lower <= upper do
    val = %Bounds{lower: upper, upper: upper}
    slicer_accum(lower, upper - 1, [val | acc])
  end
end

# defimpl Collectable, for: AbstractEVM.Bounds do
#   alias AbstractEVM.Bounds

#   def into(%AbstractEVM.Bounds{} = bounds_orig) do
#     collector_fun = fn
#       bounds_acc, {:cont, %AbstractEVM.Bounds{} = bounds_new} ->
#         Bounds.union(bounds_acc, bounds_new)
#       _bounds_acc, {:cont, other} ->
#         raise ArgumentError, "cannot cast #{inspect(other)} to AbstractEVM.Bounds"
#       bounds_acc, :done ->
#         bounds_acc
#       _bounds_acc, :halt ->
#         :ok
#     end

#     {bounds_orig, collector_fun}
#   end
# end
