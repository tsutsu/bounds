defprotocol Bounds.Sliced do
  @moduledoc false

  def slice(slice, slicing_bounds)
  def value(slice)
end
