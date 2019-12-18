defmodule Bounds.SlicedBitString do
  defstruct [
    bs: <<>>,
    bounds: %Bounds{}
  ]

  @doc false
  def base(bs) when is_bitstring(bs) do
    %__MODULE__{bs: bs, bounds: %Bounds{upper: bit_size(bs)}}
  end

  def slice(%__MODULE__{bs: bs, bounds: bounds}, slicing_bounds) do
    %__MODULE__{bs: bs, bounds: Bounds.slice(bounds, slicing_bounds)}
  end

  def unslice(%__MODULE__{bs: bs} = slice) do
    %__MODULE__{slice | bounds: %Bounds{upper: bit_size(bs)}}
  end

  def to_bitstring(%__MODULE__{bs: bs, bounds: %Bounds{lower: lower, upper: upper}}) do
    bsz = upper - lower
    <<_::bitstring-size(lower), seg::bitstring-size(bsz), _::bitstring>> = bs
    seg
  end
end

defimpl Bounds.Sliced, for: Bounds.SlicedBitString do
  alias Bounds.SlicedBitString

  def bounds(%SlicedBitString{bounds: bounds}), do:
    bounds

  def slice(%SlicedBitString{} = sliced_value, slicing_bounds), do:
    SlicedBitString.slice(sliced_value, slicing_bounds)

  def unslice(%SlicedBitString{} = sliced_value), do:
    SlicedBitString.unslice(sliced_value)

  def value(%SlicedBitString{} = sliced_value), do:
    SlicedBitString.to_bitstring(sliced_value)
end

defimpl Bounds.Sliced, for: BitString do
  alias Bounds.SlicedBitString

  def bounds(bs), do:
    %Bounds{upper: bit_size(bs)}

  def slice(bs, slicing_bounds) when is_bitstring(bs), do:
    SlicedBitString.slice(SlicedBitString.base(bs), slicing_bounds)

  def unslice(bs) when is_bitstring(bs), do:
    SlicedBitString.base(bs)

  def value(bs) when is_bitstring(bs), do:
    bs
end

defimpl Inspect, for: Bounds.SlicedBitString do
  import Inspect.Algebra
  alias Bounds.SlicedBitString

  def inspect(%SlicedBitString{} = slice, opts) do
    bs = SlicedBitString.to_bitstring(slice)

    concat([
      color("|", :binary, opts),
      to_doc(bs, opts),
      color("|", :binary, opts)
    ])
  end
end
