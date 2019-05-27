defmodule Bounds.Slice do
  defdelegate slice(slice, slicing_bounds), to: Bounds.Sliced
  defdelegate value(slice), to: Bounds.Sliced

  def from_binary(bin), do: Bounds.SlicedBinary.base(bin)
  def from_enum(enum, size \\ nil), do: Bounds.SlicedEnumerable.base(enum, size)
  def from_stream(enum), do: Bounds.SlicedEnumerable.base(enum, :infinity)
end
