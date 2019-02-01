defmodule FDBLayer.Index.Aggregate.Sum do
  def default() do
    0
  end

  def coder() do
    FDB.Coder.SignedLittleEndianInteger.new()
  end

  def create(value) do
    {FDB.Option.mutation_type_add(), value}
  end

  def update(old, new) do
    {FDB.Option.mutation_type_add(), new - old}
  end

  def delete(value) do
    {FDB.Option.mutation_type_add(), -value}
  end
end
