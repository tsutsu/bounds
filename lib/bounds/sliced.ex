defprotocol Bounds.Sliced do
  def slice(slice, slicing_bounds)
  def value(slice)
end
