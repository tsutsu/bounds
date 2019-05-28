defmodule Bounds.SlicedBinary do
  defstruct [
    bin: <<>>,
    bounds: %Bounds{}
  ]

  @doc false
  def base(bin) when is_binary(bin) do
    %__MODULE__{bin: bin, bounds: %Bounds{lower: 0, upper: byte_size(bin)}}
  end

  def slice(%__MODULE__{bin: bin, bounds: bounds}, slicing_bounds) do
    %__MODULE__{bin: bin, bounds: Bounds.slice(bounds, slicing_bounds)}
  end

  def to_binary(%__MODULE__{bin: bin, bounds: %Bounds{lower: lower, upper: upper}}) do
    :binary.part(bin, lower, upper - lower)
  end
end

defimpl Bounds.Sliced, for: Bounds.SlicedBinary do
  alias Bounds.SlicedBinary

  def slice(%SlicedBinary{} = sliced_value, slicing_bounds), do:
    SlicedBinary.slice(sliced_value, slicing_bounds)

  def value(%SlicedBinary{} = sliced_value), do:
    SlicedBinary.to_binary(sliced_value)
end
