defmodule FDBLayer.Index.Value do
  @enforce_keys [:name, :coder, :path, :projection]
  defstruct [:name, :coder, :path, :projection]

  def new(opts) do
    struct!(__MODULE__, opts)
  end
end

defimpl FDBLayer.Index.Protocol, for: FDBLayer.Index.Value do
  alias FDB.Transaction
  alias FDBLayer.Projection

  def init(index, transaction, root_directory) do
    directory = FDB.Directory.create_or_open(root_directory, transaction, index.path)
    coder = Map.update!(index.coder, :key, &FDB.Coder.Subspace.new(directory, &1))
    %{index | coder: coder}
  end

  def create(index, transaction, new_record) do
    [{key, value}] = Projection.apply(index.projection, new_record)
    :ok = Transaction.set(transaction, key, value, %{coder: index.coder})
  end

  def update(index, transaction, old_record, new_record) do
    new = [{new_key, new_value}] = Projection.apply(index.projection, new_record)
    old = [{old_key, _old_value}] = Projection.apply(index.projection, old_record)

    if new != old do
      :ok = Transaction.clear(transaction, old_key, %{coder: index.coder})
      :ok = Transaction.set(transaction, new_key, new_value, %{coder: index.coder})
    else
      :ok
    end
  end

  def delete(index, transaction, current_record) do
    [{key, _}] = Projection.apply(index.projection, current_record)
    :ok = Transaction.clear(transaction, key, %{coder: index.coder})
  end

  def scan(index, database_or_transaction, key_selector_range) do
    Transaction.get_range_stream(database_or_transaction, key_selector_range, %{
      coder: index.coder
    })
  end
end
