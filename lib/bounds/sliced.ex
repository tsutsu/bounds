defprotocol Bounds.Sliced do
  @moduledoc false

  def bounds(slice)
  def slice(slice, slicing_bounds)
  def unslice(slice)
  def value(slice)
end
