defmodule Bounds.Slice do
  defdelegate bounds(slice), to: Bounds.Sliced
  defdelegate slice(slice, slicing_bounds), to: Bounds.Sliced
  defdelegate unslice(slice), to: Bounds.Sliced
  defdelegate value(slice), to: Bounds.Sliced

  def reslice(slice, slicing_bounds) do
    unslice(slice) |> slice(slicing_bounds)
  end

  def constrain!(slice, slicing_bounds) do
    superset_bounds = bounds(slice)
    slicing_bounds = Bounds.new(slicing_bounds)
    if Bounds.subset?(superset_bounds, slicing_bounds) do
      reslice(slice, slicing_bounds)
    else
      raise ArgumentError, "#{inspect slicing_bounds} fall outside of existing bounds #{inspect superset_bounds}"
    end
  end

  def from_binary(bin), do: Bounds.SlicedBinary.base(bin)
  def from_enum(enum, size \\ nil), do: Bounds.SlicedEnumerable.base(enum, size)
  def from_stream(enum), do: Bounds.SlicedEnumerable.base(enum, :infinity)
end
