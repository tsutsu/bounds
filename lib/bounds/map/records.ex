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
