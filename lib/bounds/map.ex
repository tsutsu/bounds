defmodule Bounds.Map.Records do
  require Record
  import Record

  defrecord :interval, [
    lower: -1,
    upper: -1,
    priority: -1,
    value: nil
  ]

  defrecord :tree_node, [
    max: -1,
    height: -1,
    data: nil,
    left: nil,
    right: nil
  ]
end

defmodule Bounds.Map do
  import Bounds.Map.Records

  defstruct [
    size: 0,
    root: nil
  ]

  def new, do: %__MODULE__{}


  # Map-like interface

  def put(%__MODULE__{} = map, bounds, value), do:
    insert(map, {bounds, value})

  def delete(%__MODULE__{root: tnode0, size: size0} = map, %Bounds{lower: lower, upper: upper}) do
    result =
      exact_matches(tnode0, interval(lower: lower, upper: upper), [])
      |> newest_interval()

    case result do
      {:ok, interval() = ival} ->
        case root_after_delete(tnode0, ival) do
          {:changed, tnode1} ->
            %__MODULE__{root: tnode1, size: size0 - 1}
          :same ->
            map
        end
      :error ->
        map
    end
  end

  def keys(%__MODULE__{} = map) do
    Enum.reduce(map, [], fn {k, _}, acc -> [k | acc] end)
    |> Enum.reverse()
  end

  def values(%__MODULE__{} = map) do
    Enum.reduce(map, [], fn {_, v}, acc -> [v | acc] end)
    |> Enum.reverse()
  end

  def fetch(%__MODULE__{root: tnode}, loc) when is_integer(loc) do
    result =
      all_overlapping(tnode, interval(lower: loc, upper: loc + 1), [])
      |> newest_interval()

    case result do
      {:ok, interval(value: v)} -> {:ok, v}
      :error -> :error
    end
  end

  def get(%__MODULE__{} = map, loc, default \\ nil) when is_integer(loc) do
    case fetch(map, loc) do
      {:ok, v} -> v
      :error -> default
    end
  end

  def fetch!(%__MODULE__{} = map, loc) when is_integer(loc) do
    case fetch(map, loc) do
      {:ok, v} -> v
      :error -> raise KeyError, key: loc, term: map
    end
  end

  def all_at(%__MODULE__{root: tnode}, loc) when is_integer(loc) do
    all_overlapping(tnode, interval(lower: loc, upper: loc + 1), [])
    |> Enum.sort_by(fn interval(priority: p, value: v) -> {-p, v} end)
    |> Enum.map(fn interval(value: v) -> v end)
  end

  def versions_at(%__MODULE__{root: tnode}, loc) when is_integer(loc) do
    all_overlapping(tnode, interval(lower: loc, upper: loc + 1), [])
    |> Enum.sort_by(fn interval(priority: p, value: v) -> {p, v} end)
    |> Enum.map(fn interval(priority: p, value: v) -> {p, v} end)
  end

  def edges(%__MODULE__{root: tnode}) do
    edges(tnode, [])
    |> Enum.reverse()
  end

  defp edges(nil, acc), do: acc
  defp edges(tree_node(data: interval(lower: lower, upper: upper, priority: p), left: left, right: right), acc) do
    src_vertex = {%Bounds{lower: lower, upper: upper}, p}
    acc = edge(src_vertex, left, acc)
    acc = edge(src_vertex, right, acc)
    acc
  end

  defp edge(_src_vertex, nil, acc), do: acc
  defp edge(src_vertex, tree_node(data: interval(lower: lower, upper: upper, priority: p)) = dest, acc) do
    dest_vertex = {%Bounds{lower: lower, upper: upper}, p}
    acc = [{src_vertex, dest_vertex} | acc]
    edges(dest, acc)
  end


  def all_overlapping(%__MODULE__{root: tnode}, %Bounds{lower: lower, upper: upper}), do:
    all_overlapping(tnode, interval(lower: lower, upper: upper), [])

  def insert(%__MODULE__{root: tnode0, size: size0}, {%Bounds{lower: lower, upper: upper}, value}) do
    tnode1 = root_after_insert(tnode0, interval(lower: lower, upper: upper, priority: size0, value: value))
    %__MODULE__{root: tnode1, size: size0 + 1}
  end


  defmacrop updated_tree_node(tnode0, args) do
    quote do
      update_max(tree_node(unquote(tnode0), unquote(args)))
    end
  end

  defp newest_interval([]), do: :error
  defp newest_interval(l) when is_list(l) do
    newest = Enum.min_by(l, fn interval(priority: p, value: v) -> {-p, v} end)
    {:ok, newest}
  end


  defp exact_matches(nil, _ival, acc), do: acc
  defp exact_matches(tree_node(data: interval(lower: t1_l, upper: t1_u) = ival, left: left, right: right), interval(lower: t2_l, upper: t2_u) = t2, acc) do
    acc = if t1_l == t2_l and t1_u == t2_u do
      [ival | acc]
    else
      acc
    end

    acc = case left do
      tree_node(max: left_max) when left_max > t2_l ->
        exact_matches(left, t2, acc)
      _ ->
        acc
    end

    acc = case {t1_l < t2_u, right} do
      {true, tree_node(max: right_max)} when right_max > t2_l ->
        exact_matches(right, t2, acc)
      _ ->
        acc
    end

    acc
  end


  defp all_overlapping(nil, _, acc), do: acc
  defp all_overlapping(tree_node(data: interval(lower: t1_l, upper: t1_u) = ival, left: left, right: right), interval(lower: t2_l, upper: t2_u) = t2, acc) do
    overlap1 = t1_l < t2_u
    overlap2 = t2_l < t1_u

    acc = if overlap1 and overlap2 do
      [ival | acc]
    else
      acc
    end

    acc = case left do
      tree_node(max: left_max) when left_max > t2_l ->
        all_overlapping(left, t2, acc)
      _ ->
        acc
    end

    acc = case {overlap1, right} do
      {true, tree_node(max: right_max)} when right_max > t2_l ->
        all_overlapping(right, t2, acc)
      _ ->
        acc
    end

    acc
  end

  @doc false
  def root_after_insert(nil, interval(upper: upper) = ival) do
    tree_node(data: ival, max: upper, height: 1)
  end

  def root_after_insert(tree_node(data: interval(lower: data_lower), left: left0, right: right0) = tnode0, interval(lower: ival_lower) = ival) do
    tnode1 = if ival_lower < data_lower do
      left1 = root_after_insert(left0, ival)
      updated_tree_node(tnode0, left: left1, height: get_height(left1, right0))
    else
      right1 = root_after_insert(right0, ival)
      updated_tree_node(tnode0, right: right1, height: get_height(left0, right1))
    end

    balance(tnode1, ival_lower)
  end

  @doc false
  def root_after_delete(nil, _), do: :same
  def root_after_delete(tree_node(data: ival, left: nil, right: nil) = n, ival) do
    IO.inspect(n, label: "deleting leaf")
    {:changed, nil}
  end
  def root_after_delete(tree_node(data: ival, left: tree_node() = left0, right: nil) = n, ival) do
    IO.inspect(n, label: "deleting lbranch")
    {:changed, left0}
  end
  def root_after_delete(tree_node(data: ival, left: nil, right: tree_node() = right0) = n, ival) do
    IO.inspect(n, label: "deleting rbranch")
    {:changed, right0}
  end
  def root_after_delete(tree_node(data: ival, left: tree_node() = _left0, right: tree_node() = _right0), ival), do:
    raise ArgumentError, "not implemented"
  def root_after_delete(tree_node(left: left0, right: right0) = tnode0, ival) do
    case root_after_delete(left0, ival) do
      {:changed, left1} ->
        {:changed, updated_tree_node(tnode0, left: left1, height: get_height(left1, right0))}
      :same ->
        case root_after_delete(right0, ival) do
          {:changed, right1} ->
            {:changed, updated_tree_node(tnode0, right: right1, height: get_height(left0, right1))}
          :same ->
            :same
        end
    end
  end

  defp balance(nil, _low_key), do: nil
  defp balance(tree_node(left: left, right: right) = tnode0, low_key) when is_integer(low_key) do
    case get_height(left) - get_height(right) do
      delta when delta > 1 ->
        maybe_rotate(:right, tnode0, left, low_key)
      delta when delta < -1 ->
        maybe_rotate(:left, tnode0, right, low_key)
      _ ->
        tnode0
    end
  end

  defp maybe_rotate(_, tnode0, nil, _), do: tnode0
  defp maybe_rotate(:right, tnode0, tree_node(data: interval(lower: left_lower)) = left, low_key) do
    tnode1 = case low_key < left_lower do
      true -> tnode0
      false -> tree_node(tnode0, left: rotate_left(left))
    end
    rotate_right(tnode1)
  end
  defp maybe_rotate(:left, tnode0, tree_node(data: interval(lower: right_lower)) = right, low_key) do
    tnode1 = case low_key < right_lower do
      true -> tree_node(tnode0, right: rotate_right(right))
      false -> tnode0
    end
    rotate_left(tnode1)
  end

  defp rotate_right(tree_node(left: tree_node(left: ll0, right: lr0) = l0, right: r0) = tnode0) do
    tnode1 = updated_tree_node(tnode0, left: lr0, height: get_height(lr0, r0))
    updated_tree_node(l0, right: tnode1, height: get_height(ll0, tnode1))
  end

  defp rotate_left(tree_node(left: l0, right: tree_node(left: rl0, right: rr0) = r0) = tnode0) do
    tnode1 = updated_tree_node(tnode0, right: rl0, height: get_height(l0, rl0))
    updated_tree_node(r0, left: tnode1, height: get_height(tnode1, rr0))
  end

  @compile inline: [get_max: 1, update_max: 1, get_height: 1, get_height: 2]

  defp get_max(tree_node(max: max)), do: max
  defp get_max(nil), do: 0

  defp update_max(tree_node(data: interval(upper: data_upper), left: left, right: right) = tnode0) do
    max = Kernel.max(Kernel.max(get_max(left), get_max(right)), data_upper)
    tree_node(tnode0, max: max)
  end

  defp get_height(left, right), do:
    Kernel.max(get_height(left), get_height(right)) + 1

  defp get_height(tree_node(height: height)), do: height
  defp get_height(nil), do: 0
end

defimpl Enumerable, for: Bounds.Map do
  alias Bounds.Map, as: BMap
  import Bounds.Map.Records

  def count(%BMap{size: size}) do
    {:ok, size}
  end

  def member?(%BMap{} = bmap, {%Bounds{} = bounds, _} = pair) do
    BMap.all_overlapping(bmap, bounds)
    |> Enum.member?(pair)
  end
  def member?(%BMap{}, _), do: {:ok, false}

  def reduce(%BMap{root: tnode}, acc, fun) do
    reduce_impl([tnode], acc, fun)
  end

  defp reduce_impl(_work, {:halt, acc}, _fun), do:
    {:halted, acc}
  defp reduce_impl(work, {:suspend, acc}, fun), do:
    {:suspended, acc, &reduce_impl(work, &1, fun)}
  defp reduce_impl([], {:cont, acc}, _fun), do:
    {:done, acc}
  defp reduce_impl([tree_node(data: ival, left: left, right: right) | work], {:cont, acc}, fun) do
    left_part = if left, do: [left], else: []
    right_part = if right, do: [right], else: []
    reduce_impl(left_part ++ [ival] ++ right_part ++ work, {:cont, acc}, fun)
  end
  defp reduce_impl([interval(lower: lower, upper: upper, value: value) | work], {:cont, acc}, fun) do
    elem = {%Bounds{lower: lower, upper: upper}, value}
    reduce_impl(work, fun.(elem, acc), fun)
  end

  def slice(%BMap{}) do
    {:error, __MODULE__}
  end
end

defimpl Collectable, for: Bounds.Map do
  import Bounds.Map.Records

  def into(%Bounds.Map{root: tnode, size: size}), do:
    {[tnode | size], &collector/2}

  defp collector(acc, cmd)
  defp collector([tnode | size], {:cont, {%Bounds{lower: lower, upper: upper}, value}}), do:
    [Bounds.Map.root_after_insert(tnode, interval(lower: lower, upper: upper, priority: size, value: value)) | size + 1]
  defp collector(_tnode_acc, {:cont, {other, _}}), do:
    raise ArgumentError, "cannot cast #{inspect(other)} to Bounds"
  defp collector(_tnode_acc, {:cont, other}), do:
    raise ArgumentError, "#{inspect(other)} is not a key-value pair"
  defp collector([tnode | size], :done), do:
    %Bounds.Map{root: tnode, size: size}
  defp collector(_acc, :halt), do:
    :ok
end
