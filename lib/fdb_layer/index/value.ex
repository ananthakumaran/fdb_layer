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
  alias FDBLayer.Changeset

  def init(index, transaction, root_directory) do
    directory = FDB.Directory.create_or_open(root_directory, transaction, index.path)
    coder = Map.update!(index.coder, :key, &FDB.Coder.Subspace.new(directory, &1))
    %{index | coder: coder}
  end

  def create(index, transaction, new_record) do
    Projection.apply(index.projection, new_record)
    |> Enum.each(fn {key, value} ->
      :ok = Transaction.set(transaction, key, value, %{coder: index.coder})
    end)

    :ok
  end

  def update(index, transaction, old_record, new_record) do
    new = Projection.apply(index.projection, new_record)
    old = Projection.apply(index.projection, old_record)
    changeset = Changeset.construct(old, new)

    Enum.each(changeset.created, fn {key, value} ->
      :ok = Transaction.set(transaction, key, value, %{coder: index.coder})
    end)

    Enum.each(changeset.updated, fn {key, _old_value, new_value} ->
      :ok = Transaction.set(transaction, key, new_value, %{coder: index.coder})
    end)

    Enum.each(changeset.deleted, fn {key, _value} ->
      :ok = Transaction.clear(transaction, key, %{coder: index.coder})
    end)

    :ok
  end

  def delete(index, transaction, current_record) do
    Projection.apply(index.projection, current_record)
    |> Enum.each(fn {key, _} ->
      :ok = Transaction.clear(transaction, key, %{coder: index.coder})
    end)

    :ok
  end

  def scan(index, database_or_transaction, key_selector_range) do
    Transaction.get_range_stream(database_or_transaction, key_selector_range, %{
      coder: index.coder
    })
  end
end
