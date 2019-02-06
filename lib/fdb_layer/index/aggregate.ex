defmodule FDBLayer.Index.Aggregate do
  alias FDB.Transaction

  @enforce_keys [:name, :coder, :path, :projection, :type]
  defstruct [:name, :coder, :path, :projection, :type]

  def new(opts) do
    struct!(__MODULE__, opts)
  end

  def fetch_one(index, transaction, key \\ "") do
    fetch_one_q(index, transaction, key)
    |> FDB.Future.await() || index.type.default()
  end

  def fetch_one_q(index, transaction, key \\ "") do
    Transaction.get_q(transaction, key, %{coder: index.coder})
  end
end

defimpl FDBLayer.Index.Protocol, for: FDBLayer.Index.Aggregate do
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
      index.type.create(value)
      |> atomic(index, transaction, key)
    end)

    :ok
  end

  def update(index, transaction, old_record, new_record) do
    new = Projection.apply(index.projection, new_record)
    old = Projection.apply(index.projection, old_record)
    changeset = Changeset.construct(old, new)

    Enum.each(changeset.created, fn {key, value} ->
      index.type.create(value)
      |> atomic(index, transaction, key)
    end)

    Enum.each(changeset.updated, fn {key, old_value, new_value} ->
      index.type.update(old_value, new_value)
      |> atomic(index, transaction, key)
    end)

    Enum.each(changeset.deleted, fn {key, value} ->
      index.type.delete(value)
      |> atomic(index, transaction, key)
    end)
  end

  def delete(index, transaction, current_record) do
    Projection.apply(index.projection, current_record)
    |> Enum.each(fn {key, value} ->
      index.type.delete(value)
      |> atomic(index, transaction, key)
    end)

    :ok
  end

  def scan(index, database_or_transaction, key_selector_range) do
    Transaction.get_range_stream(database_or_transaction, key_selector_range, %{
      coder: index.coder
    })
  end

  defp atomic(nil, _, _, _) do
    :ok
  end

  defp atomic({mutation_type, value}, index, transaction, key) do
    :ok = Transaction.atomic_op(transaction, key, mutation_type, value, %{coder: index.coder})
  end
end
