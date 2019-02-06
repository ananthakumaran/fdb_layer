defmodule FDBLayer.Index.Primary do
  alias FDB.Transaction
  @enforce_keys [:name, :coder, :path, :projection]
  defstruct [:name, :coder, :path, :projection]

  def new(opts) do
    struct!(__MODULE__, opts)
  end

  def fetch_one(index, transaction, id) do
    fetch_one_q(index, transaction, id)
    |> FDB.Future.await()
  end

  def fetch_one_q(index, transaction, id) do
    Transaction.get_q(transaction, id, %{coder: index.coder})
  end
end

defimpl FDBLayer.Index.Protocol, for: FDBLayer.Index.Primary do
  alias FDB.Transaction
  alias FDBLayer.Projection
  alias FDBLayer.Index.Primary

  def init(index, transaction, root_directory) do
    directory = FDB.Directory.create_or_open(root_directory, transaction, index.path)
    coder = Map.update!(index.coder, :key, &FDB.Coder.Subspace.new(directory, &1))
    %{index | coder: coder}
  end

  def create(index, transaction, new_record) do
    [{key, value}] = Projection.apply(index.projection, new_record)
    current = Primary.fetch_one(index, transaction, key)

    if current do
      raise FDBLayer.DuplicateRecordError, """
      A record with primary key `#{key}` already exists.
      Existing Record: #{inspect(current)}
      """
    end

    :ok = Transaction.set(transaction, key, value, %{coder: index.coder})
  end

  def update(index, transaction, _old_record, new_record) do
    [{key, value}] = Projection.apply(index.projection, new_record)
    :ok = Transaction.set(transaction, key, value, %{coder: index.coder})
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
