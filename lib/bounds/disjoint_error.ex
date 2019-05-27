defmodule Bounds.DisjointError do
  defexception [:message]

  @impl true
  def exception({bounds_a, bounds_b}) do
    msg = "#{inspect(bounds_a)} cannot union with #{inspect(bounds_b)}"
    %__MODULE__{message: msg}
  end
end
