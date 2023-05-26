defmodule Bounds.Map do
  import Bounds.Map.Records
  alias Bounds.Map.Impl

  defstruct [
    size: 0,
    priority_seq: 0,
    offset: 0,
    root: nil
  ]

  def new, do: %__MODULE__{}


  @doc ~S"""
  Inserts a interval into the given Bounds.Map
  The Bounds.Map is based on a BST, which will be rebalanced if necessary.

  ## Examples

  iex(1)> alias Bounds.Map, as: BMap
  iex(2)> mp=BMap.new()
  iex(3)> mp = BMap.insert(mp, Bounds.new(1, 4), 24)
  %Bounds.Map{
  size: 1,
  priority_seq: 1,
  offset: 0,
  root: {:tree_node, 5, 1, {:interval, 1, 5, 0, 24}, nil, nil}
  }

  """
  def insert(%__MODULE__{root: tnode0, size: size0} = bset0, interval() = ival) do
    {tnode1, size1} = Impl.insert({tnode0, size0}, ival)
    %__MODULE__{bset0 | root: tnode1, size: size1}
  end

  def insert(%__MODULE__{root: tnode0, priority_seq: pseq0, size: size0} = bset0, boundable, value) do
    priority = pseq0
    {%Bounds{lower: lower, upper: upper}, _} = Coerce.coerce(boundable, %Bounds{})
    {tnode1, size1} = Impl.insert({tnode0, size0}, interval(lower: lower, upper: upper, priority: priority, value: value))
    %__MODULE__{bset0 | root: tnode1, priority_seq: pseq0 + 1, size: size1}
  end

  def insert(%__MODULE__{root: tnode0, size: size0} = bset0, boundable, priority, value) do
    {%Bounds{lower: lower, upper: upper}, _} = Coerce.coerce(boundable, %Bounds{})
    {tnode1, size1} = Impl.insert({tnode0, size0}, interval(lower: lower, upper: upper, priority: priority, value: value))
    %__MODULE__{bset0 | root: tnode1, size: size1}
  end

  @doc ~S"""
  select all boundables that match the given selector and boundable
  The selector_name can take following values:

  * `:coincidents` - select all boundables that are coincide exactly with the given boundable (default)
  * `:overlaps` - select all boundables that overlap with the given boundable
  * `:covers` - select all boundables that are covered by the given boundable
  * `:strict_subsets` - select all boundables that are covered by the given boundable but do not coincide with it

  ## Examples

  iex(1)> alias Bounds.Map, as: BMap
  iex(2)> mp=BMap.new()
  iex(3)> mp = BMap.insert(mp, Bounds.new(1, 4), 24)
  iex(4)> mp = BMap.insert(mp, Bounds.new(0, 3), 101)
  iex(5)> mp = BMap.insert(mp, Bounds.new(3, 2), 16)
  iex(6)> mp = BMap.insert(mp, Bounds.new(0, 2), 10)
  iex(7)> mp = BMap.insert(mp, Bounds.new(0, 3), 102)

  iex(8)> BMap.all(mp, Bounds.new(0,3), :coincidents)
  [{0...3, 4, 102}, {0...3, 1, 101}]

  iex(9)> BMap.all(mp, Bounds.new(0,4), :coincidents)
  []

  iex(10)> BMap.all(mp, Bounds.new(0,4), :overlaps)

  [
   {3...5, 2, 16},
   {0...3, 4, 102},
   {0...3, 1, 101},
   {0...2, 3, 10},
   {1...5, 0, 24}
  ]

  iex(11)> BMap.all(mp, Bounds.new(0,4), :covers)
  [{0...3, 4, 102}, {0...3, 1, 101}, {0...2, 3, 10}]

  iex(12)> BMap.all(mp, Bounds.new(0,3), :strict_subsets)
  [{0...2, 3, 10}]
  """
  def all(%__MODULE__{} = bmap, boundable, selector_name \\ :coincidents), do:
    do_match(bmap, {selector_name, boundable}, :all, :triples)



  @doc ~S"""
  select the highest priority boundable that matches the given selector and boundable

  ## Examples

  iex(1)> alias Bounds.Map, as: BMap
  iex(2)> mp = BMap.new()
  iex(3)> mp = BMap.insert(mp, Bounds.new(1, 4), 24)
  iex(4)> mp = BMap.insert(mp, Bounds.new(0, 3), 101)
  iex(5)> mp = BMap.insert(mp, Bounds.new(3, 2), 16)
  iex(6)> mp = BMap.insert(mp, Bounds.new(0, 2), 10)
  iex(7)> mp = BMap.insert(mp, Bounds.new(0, 3), 102)
  """
  def highest(%__MODULE__{} = bmap, boundable, selector_name \\ :coincidents), do:
    do_match(bmap, {selector_name, boundable}, :highest, :triples)


  @doc ~S"""
  select all boundables that match the given priority

  ## Examples (using the bound map in above functions)

  iex(11)> BMap.layer(mp, 2)
  %Bounds.Map{
  size: 1,
  priority_seq: 0,
  offset: 0,
  root: {:tree_node, 5, 1, {:interval, 3, 5, 2, 16}, nil, nil}
  }

  """
  def layer(%__MODULE__{} = bmap, z), do:
    do_match(bmap, :all, {:priority, z}, :map)

  def filter(%__MODULE__{} = bmap, pred), do:
    do_match(bmap, :all, {:predicate, pred}, :map)


  def delete_all(%__MODULE__{} = bmap, boundable, selector_name \\ :coincidents), do:
    do_match(bmap, {selector_name, boundable}, :all, :delete)

  def delete_highest(%__MODULE__{} = bmap, boundable, selector_name \\ :coincidents), do:
    do_match(bmap, {selector_name, boundable}, :highest, :delete)

  def delete_layer(%__MODULE__{} = bmap, z), do:
    do_match(bmap, :all, {:priority, z}, :delete)


  @doc ~S"""
  returns a stream of keys (ranges) in the map.

  * By default this returns priority as well.
  * The above can be avoided by using opt `with_priorities: false`

  ## Examples (using the bound map in above functions)

  iex(13)> BMap.keys(mp) |> Enum.to_list()
  [{0...3, 1}, {0...2, 3}, {0...3, 4}, {1...5, 0}, {3...5, 2}]

  iex(14)> BMap.keys(mp, with_priorities: false) |> Enum.to_list()
  [0...3, 0...2, 0...3, 1...5, 3...5]
  """
  def keys(%__MODULE__{root: tnode}, opts \\ []) do
    v_stream = Impl.stream_vertices(tnode)

    if Keyword.get(opts, :with_priorities, true) do
      Stream.map(v_stream, fn interval(lower: lower, upper: upper, priority: priority) ->
        {%Bounds{lower: lower, upper: upper}, priority}
      end)
    else
      Stream.map(v_stream, fn interval(lower: lower, upper: upper) ->
        %Bounds{lower: lower, upper: upper}
      end)
    end
  end


  def values(%__MODULE__{root: tnode}) do
    Impl.stream_vertices(tnode)
    |> Stream.map(fn interval(value: value) -> value end)
  end


  @doc ~S"""
  returns a list of tuples of the form {range, priority, value}

  ## Examples (using the bound map in above functions)

  iex(16)> BMap.triples(mp) |> Enum.to_list()
  [
  {0...3, 1, 101},
  {0...2, 3, 10},
  {0...3, 4, 102},
  {1...5, 0, 24},
  {3...5, 2, 16}
  ]
  """
  def triples(%__MODULE__{root: tnode}) do
    Impl.stream_vertices(tnode)
    |> Stream.map(fn interval(lower: lower, upper: upper, priority: priority, value: value) ->
      {%Bounds{lower: lower, upper: upper}, priority, value}
    end)
  end


  def member?(%__MODULE__{root: tnode}, {%Bounds{lower: lower, upper: upper}, priority, value}) do
    Impl.coincidents(tnode, interval(lower: lower, upper: upper))
    |> Enum.any?(fn
      interval(priority: ^priority, value: ^value) -> true
      _ -> false
    end)
  end
  def member?(%__MODULE__{}, _), do: false


  @doc ~S"""
  returns the lower and upper bound (in `Bounds` form) which spans the entire map

  ## Examples (using the bound map in above functions)

  iex(17)> BMap.extent(mp)
  0...5
  """
  def extent(%__MODULE__{root: tnode}) do
    interval(lower: min_lower) = Impl.min_ival(tnode)
    interval(upper: max_upper) = Impl.max_ival(tnode)
    %Bounds{lower: min_lower, upper: max_upper}
  end



  def slice(%__MODULE__{root: tnode0, offset: offset0}, interval(lower: mask_lower, upper: mask_upper) = mask_ival) do
    Impl.overlaps(tnode0, mask_ival)
    |> Stream.map(fn interval(lower: shape_lower, upper: shape_upper) = ival ->
      slice_lower = :erlang.max(mask_lower, shape_lower) - mask_lower
      slice_upper = :erlang.min(mask_upper, shape_upper) - mask_lower
      interval(ival, lower: slice_lower, upper: slice_upper)
    end)
    |> Stream.filter(fn
      interval(lower: common, upper: common) -> false
      _ -> true
    end)
    |> Enum.into(%__MODULE__{offset: offset0 + mask_lower})
  end

  def slice(%__MODULE__{} = bmap, mask_boundable) do
    {%Bounds{lower: mask_lower, upper: mask_upper}, _} = Coerce.coerce(mask_boundable, %Bounds{})
    slice(bmap, interval(lower: mask_lower, upper: mask_upper))
  end


  def clear(%__MODULE__{} = bmap0), do:
    %__MODULE__{bmap0 | root: nil, size: 0}


  def surface(%__MODULE__{root: tnode} = bmap0) do
    {bmap, _mask} =
      Impl.stream_vertices(tnode)
      |> Enum.sort_by(fn interval(lower: lower, upper: upper, priority: priority) ->
        {priority, -lower, upper}
      end)
      |> Enum.reverse()
      |> Enum.reduce({clear(bmap0), Bounds.Set.new()}, fn ival, {bmap0, mask0} = acc0 ->
        if Bounds.Set.covers?(mask0, ival) do
          acc0
        else
          clipped_ival_parts = Bounds.Set.clip(mask0, ival, as: :negative)
          mask1 = Bounds.Set.set(mask0, ival)
          bmap1 = Enum.reduce(clipped_ival_parts, bmap0, fn part, acc ->
            insert(acc, part)
          end)

          {bmap1, mask1}
        end
      end)

    bmap
  end


  ## helpers

  def do_match(%__MODULE__{} = bmap, select_part, filter_part, return_part) do
    matching_ivals = do_match_select(select_part, bmap)
    filtered_ivals = do_match_filter(filter_part, matching_ivals)
    do_match_reduce(return_part, filtered_ivals, bmap)
  end

  defp do_match_select(:all, %__MODULE__{root: tnode}), do:
    Impl.stream_vertices(tnode) |> Enum.to_list()
  defp do_match_select({selector_name, boundable}, %__MODULE__{root: tnode}) do
    {%Bounds{lower: lower, upper: upper}, _} = Coerce.coerce(boundable, %Bounds{})
    query_ival = interval(lower: lower, upper: upper)
    do_match_select2(selector_name, tnode, query_ival)
  end

  defp do_match_select2(:coincidents, tnode, select_ival), do:
    Impl.coincidents(tnode, select_ival)
  defp do_match_select2(:overlaps, tnode, select_ival), do:
    Impl.overlaps(tnode, select_ival)
  defp do_match_select2(:covers, tnode, select_ival), do:
    Impl.covers(tnode, select_ival)
  defp do_match_select2(:strict_subsets, tnode, select_ival), do:
    Impl.covers(tnode, select_ival) -- Impl.coincidents(tnode, select_ival)

  defp do_match_filter(:all, result_set), do:
    result_set
  defp do_match_filter({:priority, n}, result_set), do:
    Impl.with_priority(result_set, n)
  defp do_match_filter(:highest, result_set), do:
    Impl.highest_priority(result_set)
  defp do_match_filter({:predicate, pred}, result_set), do:
    Enum.filter(result_set, pred)
  defp do_match_filter(:outermost, result_set) do
    %__MODULE__{root: tnode} =
      Enum.sort_by(result_set, fn interval(lower: lower, upper: upper) -> {lower, -upper} end)
      |> Enum.reduce(%__MODULE__{}, fn ival, %__MODULE__{root: tnode} = bmap_acc ->
        case Impl.covered_by(tnode, ival) do
          [] -> insert(bmap_acc, ival)
          _ -> bmap_acc
        end
      end)

    Impl.stream_vertices(tnode)
  end

  defp do_match_reduce(:intervals, result_set, _orig_bmap), do:
    result_set
  defp do_match_reduce(:triples, result_set, _orig_bmap) do
    Enum.map(result_set, fn interval(lower: lower, upper: upper, priority: priority, value: value) ->
      {%Bounds{lower: lower, upper: upper}, priority, value}
    end)
  end
  defp do_match_reduce(:map, result_set, _orig_bmap), do:
    Enum.into(result_set, new())
  defp do_match_reduce(:delete, [], orig_bmap), do:
    orig_bmap
  defp do_match_reduce(:delete, result_set, %__MODULE__{root: tnode0, size: size0} = orig_bmap) do
    {tnode1, size1} = Impl.delete_matches({tnode0, size0}, result_set)
    %__MODULE__{orig_bmap | root: tnode1, size: size1}
  end
end

defimpl Enumerable, for: Bounds.Map do
  alias Bounds.Map, as: BMap

  def count(%BMap{size: size}) do
    {:ok, size}
  end

  def member?(%BMap{} = bmap, triple) do
    {:ok, BMap.member?(bmap, triple)}
  end

  def reduce(%BMap{} = bmap, acc, fun) do
    Enumerable.reduce(BMap.triples(bmap), acc, fun)
  end

  def slice(%BMap{}) do
    {:error, __MODULE__}
  end
end

defimpl Collectable, for: Bounds.Map do
  alias Bounds.Map, as: BMap

  def into(%BMap{} = bmap), do:
    {bmap, &collector/2}

  defp collector(acc, cmd)

  defp collector(bmap, {:cont, {bounds, priority, value}}), do:
    BMap.insert(bmap, bounds, priority, value)
  defp collector(bmap, {:cont, {bounds, value}}), do:
    BMap.insert(bmap, bounds, value)
  defp collector(bmap, {:cont, ival}), do:
    BMap.insert(bmap, ival)
  defp collector(bmap, :done), do:
    bmap
  defp collector(_acc, :halt), do:
    :ok
end
