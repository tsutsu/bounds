defmodule Bounds.Map.Impl do
  import Bounds.Map.Records

  def with_priority([], _z), do: []
  def with_priority(l, z) when is_list(l) do
    Enum.filter(l, fn
      interval(priority: ^z) -> true
      _ -> false
    end)
  end

  def highest_priority([]), do: []
  def highest_priority(l) when is_list(l) do
    layers = Enum.group_by(l, fn interval(priority: p) -> p end)
    max_z = Enum.max(Map.keys(layers))
    Map.fetch!(layers, max_z)
  end


  def insert({tnode0, size0}, ival) do
    tnode1 = root_after_insert(tnode0, ival)
    {tnode1, size0 + 1}
  end


  def delete_matches(tnode_and_size, ival_enum) do
    Enum.reduce(ival_enum, tnode_and_size, fn ival, {tnode_acc0, size_acc0} ->
      case root_after_delete(tnode_acc0, ival) do
        {:changed, tnode_acc1} ->
          {tnode_acc1, size_acc0 - 1}
        :same ->
          {tnode_acc0, size_acc0}
      end
    end)
  end


  def coincidents(tnode, ival), do:
    coincidents(tnode, ival, [])

  defp coincidents(nil, _ival, acc), do: acc
  defp coincidents(tree_node(data: interval(lower: t1_l, upper: t1_u) = ival, left: left, right: right), interval(lower: t2_l, upper: t2_u) = t2, acc) do
    acc = if t1_l == t2_l and t1_u == t2_u do
      [ival | acc]
    else
      acc
    end

    acc = case left do
      tree_node(max: left_max) when left_max > t2_l ->
        coincidents(left, t2, acc)
      _ ->
        acc
    end

    acc = case {t1_l < t2_u, right} do
      {true, tree_node(max: right_max)} when right_max > t2_l ->
        coincidents(right, t2, acc)
      _ ->
        acc
    end

    acc
  end


  def overlaps(tnode, ival), do:
    overlaps(tnode, ival, [])

  defp overlaps(nil, _, acc), do: acc
  defp overlaps(tree_node(data: interval(lower: t1_l, upper: t1_u) = ival, left: left, right: right), interval(lower: t2_l, upper: t2_u) = t2, acc) do
    overlap1 = t1_l < t2_u
    overlap2 = t2_l < t1_u

    acc = if overlap1 and overlap2 do
      [ival | acc]
    else
      acc
    end

    acc = case left do
      tree_node(max: left_max) when left_max > t2_l ->
        overlaps(left, t2, acc)
      _ ->
        acc
    end

    case {overlap1, right} do
      {true, tree_node(max: right_max)} when right_max > t2_l ->
        overlaps(right, t2, acc)
      _ ->
        acc
    end
  end


  def covers(tnode, interval(lower: q_lower, upper: q_upper) = ival) do
    overlaps(tnode, ival, [])
    |> Enum.filter(fn
      interval(lower: match_lower, upper: match_upper) when match_lower >= q_lower and match_upper <= q_upper -> true
      _ -> false
    end)
  end


  def covered_by(tnode, interval(lower: q_lower, upper: q_upper) = ival) do
    overlaps(tnode, ival, [])
    |> Enum.filter(fn
      interval(lower: match_lower, upper: match_upper) when q_lower >= match_lower and q_upper <= match_upper -> true
      _ -> false
    end)
  end

  def vertices(tnode) do
    vertices_visit_vertex(tnode, [])
  end

  defp vertices_visit_vertex(nil, acc), do: acc
  defp vertices_visit_vertex(tree_node(data: ival, left: left, right: right), acc0) do
    acc1 = vertices_visit_vertex(left, acc0)
    acc2 = [ival | acc1]
    vertices_visit_vertex(right, acc2)
  end


  def edges(tnode), do:
    edges_visit_vertex(tnode, [])

  defp edges_visit_vertex(nil, acc), do: acc
  defp edges_visit_vertex(tree_node(data: interval() = src_vertex, left: left, right: right), acc0) do
    acc1 = edges_visit_edge(src_vertex, left, acc0)
    edges_visit_edge(src_vertex, right, acc1)
  end

  defp edges_visit_edge(_src_vertex, nil, acc), do: acc
  defp edges_visit_edge(src_vertex, tree_node(data: interval() = dest_vertex) = dest_branch, acc0) do
    acc1 = [{src_vertex, dest_vertex} | acc0]
    edges_visit_vertex(dest_branch, acc1)
  end


  def stream_vertices(tnode) do
    iter0 = vertex_iterator(tnode, [])

    Stream.unfold(iter0, fn
      [] ->
        nil
      iter_acc0 ->
        {:cont, val, iter_acc1} = next_vertex(iter_acc0)
        {val, iter_acc1}
    end)
  end


  defp vertex_iterator(nil, call_stack), do: call_stack
  defp vertex_iterator(tree_node(left: nil) = tnode, call_stack), do:
    [tnode | call_stack]
  defp vertex_iterator(tree_node(left: left) = tnode, call_stack), do:
    vertex_iterator(left, [tnode | call_stack])


  defp next_vertex([]), do: :halt
  defp next_vertex([tree_node(data: ival, right: right) | call_stack]), do:
    {:cont, ival, vertex_iterator(right, call_stack)}


  ## helpers

  defmacrop updated_tree_node(tnode0, args) do
    quote do
      update_max(tree_node(unquote(tnode0), unquote(args)))
    end
  end

  defp root_after_insert(nil, interval(upper: upper) = ival), do:
    tree_node(data: ival, max: upper, height: 1)
  defp root_after_insert(tree_node(data: interval(lower: data_lower), left: left0, right: right0) = tnode0, interval(lower: ival_lower) = ival) do
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
  defp root_after_delete(nil, _), do: :same
  defp root_after_delete(tree_node(data: ival, left: nil, right: nil), ival) do
    {:changed, nil}
  end
  defp root_after_delete(tree_node(data: ival, left: tree_node() = left0, right: nil), ival) do
    {:changed, left0}
  end
  defp root_after_delete(tree_node(data: ival, left: nil, right: tree_node() = right0), ival) do
    {:changed, right0}
  end
  defp root_after_delete(tree_node(data: ival, left: tree_node() = left0, right: tree_node() = right0) = tnode0, ival) do
    right_min_ival = min_ival(right0)
    {:changed, right1} = root_after_delete(right0, right_min_ival)
    {:changed, updated_tree_node(tnode0, data: right_min_ival, right: right1, height: get_height(left0, right1))}
  end
  defp root_after_delete(tree_node(left: left0, right: right0) = tnode0, ival) do
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

  def min_ival(nil), do: interval(lower: 0, upper: 0)
  def min_ival(tree_node(data: ival, left: nil)), do: ival
  def min_ival(tree_node(left: left)), do: min_ival(left)

  def max_ival(nil), do: interval(lower: 0, upper: 0)
  def max_ival(interval() = ival), do: ival
  def max_ival(tree_node(data: center, left: left, right: right)) do
    Enum.max_by([center, left, right], fn
      interval(upper: u) -> u
      tree_node(max: m) -> m
      nil -> 0
    end)
    |> max_ival()
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
