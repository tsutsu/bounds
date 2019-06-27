defmodule Bounds.Set do
  use Bitwise

  import Bounds.Map.Records
  alias Bounds.Map.Impl

  defstruct [
    root: nil,
    segments: 0
  ]

  @infinityish 1.0e100

  def new, do: %__MODULE__{}

  def new(coerceable) do
    {bounds, _} = Coerce.coerce(coerceable, %Bounds{})
    from_bounds(bounds)
  end


  def from_bounds(interval() = ival) do
    {tnode0, size0} = Impl.insert({nil, 0}, ival)
    %__MODULE__{root: tnode0, segments: size0}
  end
  def from_bounds(boundable) do
    {%Bounds{lower: lower, upper: upper}, _} = Coerce.coerce(boundable, %Bounds{})
    from_bounds(interval(lower: lower, upper: upper))
  end


  def from_map(%{root: tnode}, opts \\ []) do
    v_stream = Impl.stream_vertices(tnode)

    case Keyword.fetch(opts, :as) do
      {:ok, :mask} ->
        Enum.reduce(v_stream, from_bounds(interval(lower: 0, upper: @infinityish)), fn ival, bset ->
          unset(bset, ival)
        end)
      _ ->
        Enum.reduce(v_stream, new(), fn ival, bset ->
          set(bset, ival)
        end)
    end
  end


  def set(%__MODULE__{root: tnode0, segments: size0}, interval(lower: lower, upper: upper) = ival) do
    existing_ivals = Impl.overlaps(tnode0, interval(lower: :erlang.max(lower - 1, 0), upper: upper + 1))
    new_ival = concat_ivals([ival | existing_ivals])

    tnode1_and_size1 = Impl.delete_matches({tnode0, size0}, existing_ivals)
    {tnode2, size2} = Impl.insert(tnode1_and_size1, new_ival)

    %__MODULE__{root: tnode2, segments: size2}
  end
  def set(%__MODULE__{} = bset, boundable) do
    {%Bounds{lower: lower, upper: upper}, _} = Coerce.coerce(boundable, %Bounds{})
    set(bset, interval(lower: lower, upper: upper))
  end


  def unset(%__MODULE__{root: tnode0, segments: size0}, interval(lower: sub_lower, upper: sub_upper) = sub_ival) do
    existing_ivals = Impl.overlaps(tnode0, sub_ival)

    tnode1_and_size1 = Impl.delete_matches({tnode0, size0}, existing_ivals)

    replacement_ivals =
      Stream.flat_map(existing_ivals, fn interval(lower: shape_lower, upper: shape_upper) ->
        clip_lower = :erlang.max(sub_lower, shape_lower)
        clip_upper = :erlang.min(sub_upper, shape_upper)
        [interval(lower: shape_lower, upper: clip_lower), interval(lower: clip_upper, upper: shape_upper)]
      end)
      |> Stream.filter(fn
        interval(lower: common, upper: common) -> false
        _ -> true
      end)
      |> Enum.into(MapSet.new())

    {tnode2, size2} = Enum.reduce(replacement_ivals, tnode1_and_size1, fn ival, tnode_and_size ->
      Impl.insert(tnode_and_size, ival)
    end)

    %__MODULE__{root: tnode2, segments: size2}
  end
  def unset(%__MODULE__{} = bset, boundable) do
    {%Bounds{lower: sub_lower, upper: sub_upper}, _} = Coerce.coerce(boundable, %Bounds{})
    unset(bset, interval(lower: sub_lower, upper: sub_upper))
  end


  def union(%__MODULE__{segments: a_size} = a, %__MODULE__{segments: b_size} = b) when a_size < b_size, do:
    union(b, a)
  def union(%__MODULE__{} = a, %__MODULE__{root: b_tnode}) do
    Impl.stream_vertices(b_tnode)
    |> Enum.reduce(a, fn ival, bset_acc ->
      set(bset_acc, ival)
    end)
  end
  def union(coerceable_a, coerceable_b) do
    {%Bounds.Set{} = a, %Bounds.Set{} = b} = Coerce.coerce(coerceable_a, coerceable_b)
    union(a, b)
  end


  def complement(%__MODULE__{root: tnode}) do
    interval(lower: min_lower) = Impl.min_ival(tnode)
    interval(upper: max_upper) = Impl.max_ival(tnode)

    pre = [interval(lower: 0, upper: min_lower)]

    post = [interval(lower: max_upper, upper: @infinityish)]

    body =
      Impl.stream_vertices(tnode)
      |> Stream.transform(nil, fn
        ival, nil -> {[], ival}
        ival_b, ival_a -> {[{ival_a, ival_b}], ival_b}
      end)
      |> Stream.map(fn {interval(upper: lower), interval(lower: upper)} ->
        interval(lower: lower, upper: upper)
      end)

    Stream.concat([pre, body, post])
    |> Stream.filter(fn
      interval(lower: common, upper: common) -> false
      _ -> true
    end)
    |> Enum.into(new())
  end
  def complement(coerceable) do
    {%Bounds.Set{} = bset, _} = Coerce.coerce(coerceable, %Bounds.Set{})
    complement(bset)
  end


  def difference(%__MODULE__{} = a, %__MODULE__{root: b_tnode}) do
    Impl.stream_vertices(b_tnode)
    |> Enum.reduce(a, fn ival, bset_acc ->
      unset(bset_acc, ival)
    end)
  end
  def difference(coerceable_a, coerceable_b) do
    {%Bounds.Set{} = a, %Bounds.Set{} = b} = Coerce.coerce(coerceable_a, coerceable_b)
    difference(a, b)
  end


  def intersection(%__MODULE__{segments: a_size} = a, %__MODULE__{segments: b_size} = b) when a_size < b_size, do:
    intersection(b, a)
  def intersection(%__MODULE__{} = a, %__MODULE__{} = b) do
    %__MODULE__{root: not_b_tnode} = complement(b)

    Impl.stream_vertices(not_b_tnode)
    |> Enum.reduce(a, fn ival, bset_acc ->
      unset(bset_acc, ival)
    end)
  end
  def intersection(coerceable_a, coerceable_b) do
    {%Bounds.Set{} = a, %Bounds.Set{} = b} = Coerce.coerce(coerceable_a, coerceable_b)
    intersection(a, b)
  end


  def disjoint?(%__MODULE__{root: tnode}, interval() = ival), do:
    Impl.overlaps(tnode, ival) == []
  def disjoint?(%__MODULE__{segments: a_size} = a, %__MODULE__{segments: b_size} = b) when a_size < b_size, do:
    disjoint?(b, a)
  def disjoint?(%__MODULE__{root: a_tnode}, %__MODULE__{root: b_tnode}) do
    Impl.stream_vertices(b_tnode)
    |> Enum.all?(fn ival ->
      Impl.overlaps(a_tnode, ival) == []
    end)
  end
  def disjoint?(coerceable_a, coerceable_b) do
    {%Bounds.Set{} = a, %Bounds.Set{} = b} = Coerce.coerce(coerceable_a, coerceable_b)
    disjoint?(a, b)
  end

  def covers?(%__MODULE__{root: tnode}, interval() = ival), do:
    Impl.covered_by(tnode, ival) != []
  def covers?(%__MODULE__{root: a_tnode}, %__MODULE__{root: b_tnode}) do
    Impl.stream_vertices(b_tnode)
    |> Enum.all?(fn ival ->
      Impl.covered_by(a_tnode, ival) != []
    end)
  end
  def covers?(coerceable_a, coerceable_b) do
    {%Bounds.Set{} = a, %Bounds.Set{} = b} = Coerce.coerce(coerceable_a, coerceable_b)
    covers?(a, b)
  end


  def clip(%__MODULE__{} = mask, interval(priority: priority, value: value) = ival, opts \\ []) do
    %__MODULE__{root: tnode} = case Keyword.fetch(opts, :as) do
      {:ok, :negative} ->
        Bounds.Set.difference(Bounds.Set.from_bounds(ival), mask)
      _ ->
        Bounds.Set.intersection(Bounds.Set.from_bounds(ival), mask)
    end

    Impl.stream_vertices(tnode)
    |> Stream.map(fn ival ->
      interval(ival, priority: priority, value: value)
    end)
  end



  ## helpers

  defp concat_ivals(ivals) do
    agg_lower = Enum.map(ivals, fn interval(lower: lower) -> lower end) |> Enum.min()
    agg_upper = Enum.map(ivals, fn interval(upper: upper) -> upper end) |> Enum.max()
    interval(lower: agg_lower, upper: agg_upper)
  end
end

defimpl Inspect, for: Bounds.Set do
  import Bounds.Map.Records
  alias Bounds.Map.Impl

  import Inspect.Algebra

  def inspect(%Bounds.Set{root: tnode}, opts) do
    pre = color("(", :tuple, opts)
    post = color(")", :tuple, opts)
    sep = color(" ∪", :tuple, opts)

    bounds_vals =
      Impl.stream_vertices(tnode)
      |> Enum.map(fn interval(lower: lower, upper: upper) -> %Bounds{lower: lower, upper: upper} end)

    Inspect.Algebra.container_doc(pre, bounds_vals, post, opts, &to_doc/2, [separator: sep, break: :flex])
  end
end


defimpl Collectable, for: Bounds.Set do
  def into(%Bounds.Set{} = bset), do:
    {bset, &collector/2}

  defp collector(acc, cmd)

  defp collector(bset, {:cont, ival_or_boundable}), do:
    Bounds.Set.set(bset, ival_or_boundable)
  defp collector(bset, :done), do:
    bset
  defp collector(_acc, :halt), do:
    :ok
end
