defmodule FDBLayer.Index.Aggregate.Count do
  def default() do
    0
  end

  def create(_value) do
    {FDB.Option.mutation_type_add(), 1}
  end

  def update(_old, _new) do
    nil
  end

  def delete(_value) do
    {FDB.Option.mutation_type_add(), -1}
  end
end
