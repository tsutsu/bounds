require Coerce

Coerce.defcoercion(Integer, Bounds) do
  def coerce(point, bounds) do
    {Bounds.from_integer(point), bounds}
  end
end

Coerce.defcoercion(Tuple, Bounds) do
  def coerce({_, _} = poslen, bounds) do
    {Bounds.from_poslen(poslen), bounds}
  end
end

Coerce.defcoercion(Range, Bounds) do
  def coerce(range, bounds) do
    {Bounds.from_range(range), bounds}
  end
end

Coerce.defcoercion(Bounds, Bounds.Set) do
  def coerce(bounds, bset) do
    {Bounds.Set.from_bounds(bounds), bset}
  end
end
