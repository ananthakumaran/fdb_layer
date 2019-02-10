defmodule FDBLayer.Index.Version do
  @enforce_keys [:name, :coder, :path, :projection]
  defstruct [:name, :coder, :path, :projection]

  def new(opts) do
    struct!(__MODULE__, opts)
  end
end

defimpl FDBLayer.Index.Protocol, for: FDBLayer.Index.Version do
  alias FDB.Transaction
  alias FDBLayer.Projection

  def init(index, transaction, root_directory) do
    directory = FDB.Directory.create_or_open(root_directory, transaction, index.path)
    coder = Map.update!(index.coder, :key, &FDB.Coder.Subspace.new(directory, &1))
    %{index | coder: coder}
  end

  def create(index, transaction, new_record) do
    Projection.apply(index.projection, nil, new_record)
    |> set_versioned(transaction, index)
  end

  def update(index, transaction, old_record, new_record) do
    Projection.apply(index.projection, old_record, new_record)
    |> set_versioned(transaction, index)
  end

  def delete(index, transaction, current_record) do
    Projection.apply(index.projection, current_record, nil)
    |> set_versioned(transaction, index)
  end

  defp set_versioned(key_values, transaction, index) do
    Enum.each(key_values, fn {key, value} ->
      :ok = Transaction.set_versionstamped_key(transaction, key, value, %{coder: index.coder})
    end)

    :ok
  end

  def scan(index, database_or_transaction, key_selector_range) do
    Transaction.get_range_stream(database_or_transaction, key_selector_range, %{
      coder: index.coder
    })
  end
end
