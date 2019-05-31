{step, output_path} = case System.argv() do
  [step, output_path] -> {String.to_integer(step), output_path}
end

input = [
  {0, :a},
  {2, :b},
  {4, :c},
  {6, :d},
  {8, :d},
  {10, :d},
  {12, :d},
  # {0..5, :x},
  # {4..9, :e},
  # {5..10, :f}
]

input = Enum.slice(input, 0, step)

out_io = File.open!(output_path, [:write, :binary])

normalized_input = Enum.map(input, fn {pos, val} ->
  {Bounds.new(pos, 1), val}
end)

bmap = Enum.into(normalized_input, Bounds.Map.new())

edges = Bounds.Map.edges(bmap)

vertices = Enum.reduce(edges, MapSet.new(), fn {v1, v2}, set ->
  set |> MapSet.put(v1) |> MapSet.put(v2)
end)

vertex_names = Map.new(vertices, fn {_, p} = k ->
  {k, "b#{p}"}
end)

IO.inspect(vertex_names)

IO.binwrite(out_io, ["digraph bmap {", "\n"])

IO.binwrite(out_io, ["graph [label=\"Step #{step}\"];\n"])

Enum.each(vertices, fn {%Bounds{lower: lower, upper: upper}, _p} = v1 ->
  vertex_desc = [Map.fetch!(vertex_names, v1), " [label=\"[", to_string(lower), ", ", to_string(upper), ")\"]"]
  IO.binwrite(out_io, ["    ", vertex_desc, ";", "\n"])
end)

Enum.each(edges, fn {v1, v2} ->
  edge_desc = [Map.fetch!(vertex_names, v1), " -> ", Map.fetch!(vertex_names, v2)]
  IO.binwrite(out_io, ["    ", edge_desc, ";", "\n"])
end)

IO.binwrite(out_io, ["}", "\n"])

File.close(out_io)
