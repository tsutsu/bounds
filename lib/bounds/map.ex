defmodule Bounds.Map do
  import Bounds.Map.Records
  alias Bounds.Map.Impl

  defstruct [
    size: 0,
    priority_seq: 0,
    root: nil
  ]

  def new, do: %__MODULE__{}


  @doc false
  def insert(%__MODULE__{root: tnode0, size: size0}, interval() = ival) do
    {tnode1, size1} = Impl.insert({tnode0, size0}, ival)
    %__MODULE__{root: tnode1, size: size1}
  end

  def insert(%__MODULE__{root: tnode0, priority_seq: pseq0, size: size0}, boundable, value) do
    priority = [:"$p" | pseq0]
    {%Bounds{lower: lower, upper: upper}, _} = Coerce.coerce(boundable, %Bounds{})
    {tnode1, size1} = Impl.insert({tnode0, size0}, interval(lower: lower, upper: upper, priority: priority, value: value))
    %__MODULE__{root: tnode1, priority_seq: pseq0 + 1, size: size1}
  end

  def insert(%__MODULE__{root: tnode0, size: size0}, boundable, priority, value) do
    {%Bounds{lower: lower, upper: upper}, _} = Coerce.coerce(boundable, %Bounds{})
    {tnode1, size1} = Impl.insert({tnode0, size0}, interval(lower: lower, upper: upper, priority: priority, value: value))
    %__MODULE__{root: tnode1, size: size1}
  end


  def all(%__MODULE__{} = bmap, boundable, selector_name \\ :coincidents), do:
    do_match(bmap, {selector_name, boundable}, :all, :triples)

  def highest(%__MODULE__{} = bmap, boundable, selector_name \\ :coincidents), do:
    do_match(bmap, {selector_name, boundable}, :highest, :triples)

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


  def extent(%__MODULE__{root: tnode}) do
    interval(lower: min_lower) = Impl.min_ival(tnode)
    interval(upper: max_upper) = Impl.max_ival(tnode)
    %Bounds{lower: min_lower, upper: max_upper}
  end



  ## helpers

  def do_match(%__MODULE__{} = bmap, select_part, filter_part, return_part) do
    matching_ivals = do_match_select(select_part, bmap)
    filtered_ivals = do_match_filter(filter_part, matching_ivals)
    do_match_reduce(return_part, filtered_ivals, bmap)
  end

  defp do_match_select(:all, %__MODULE__{root: tnode}), do:
    Impl.stream_vertices(tnode)
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

  defp do_match_filter(:all, result_set), do:
    result_set
  defp do_match_filter({:priority, n}, result_set), do:
    Impl.with_priority(result_set, n)
  defp do_match_filter(:highest, result_set), do:
    Impl.highest_priority(result_set)
  defp do_match_filter({:predicate, pred}, result_set), do:
    Enum.filter(result_set, pred)

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
