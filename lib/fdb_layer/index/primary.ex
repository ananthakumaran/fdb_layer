defmodule FDBLayer.Index.Primary do
  alias FDB.Transaction
  @enforce_keys [:name, :key_expression, :value_coder]
  defstruct [:name, :path, :key_expression, :value_coder, :coder]

  def new(opts) do
    value_coder = Map.fetch!(opts, :value_coder)

    opts =
      Map.put(
        opts,
        :coder,
        FDB.Transaction.Coder.new(opts.key_expression.coder, value_coder)
      )

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
  alias FDBLayer.KeyExpression

  def init(index, transaction, root_directory) do
    directory = FDB.Directory.create_or_open(root_directory, transaction, index.path)
    coder = Map.update!(index.coder, :key, &FDB.Coder.Subspace.new(directory, &1))
    %{index | coder: coder}
  end

  def create(index, transaction, new_record) do
    id = KeyExpression.fetch(index.key_expression, new_record)
    :ok = Transaction.set(transaction, id, new_record, %{coder: index.coder})
  end

  def update(index, transaction, _old_record, new_record) do
    id = KeyExpression.fetch(index.key_expression, new_record)
    :ok = Transaction.set(transaction, id, new_record, %{coder: index.coder})
  end

  def delete(index, transaction, current_record) do
    id = KeyExpression.fetch(index.key_expression, current_record)
    :ok = Transaction.clear(transaction, id, %{coder: index.coder})
  end

  def scan(index, database_or_transaction, key_selector_range) do
    Transaction.get_range(database_or_transaction, key_selector_range, %{coder: index.coder})
  end
end
