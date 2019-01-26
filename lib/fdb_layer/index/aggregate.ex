defmodule FDBLayer.Index.Aggregate do
  alias FDB.Transaction
  @enforce_keys [:name, :key_expression, :type]
  defstruct [:name, :path, :key_expression, :type, :coder]

  def new(opts) do
    opts =
      Map.put(
        opts,
        :coder,
        FDB.Transaction.Coder.new(opts.key_expression.coder, opts.type.coder())
      )

    struct!(__MODULE__, opts)
  end

  def fetch_one(index, transaction, key \\ "") do
    fetch_one_q(index, transaction, key)
    |> FDB.Future.await()
  end

  def fetch_one_q(index, transaction, key \\ "") do
    Transaction.get_q(transaction, key, %{coder: index.coder})
  end
end

defimpl FDBLayer.Index.Protocol, for: FDBLayer.Index.Aggregate do
  alias FDB.Transaction
  alias FDBLayer.KeyExpression

  def init(index, transaction, root_directory) do
    directory = FDB.Directory.create_or_open(root_directory, transaction, index.path)
    coder = Map.update!(index.coder, :key, &FDB.Coder.Subspace.new(directory, &1))
    %{index | coder: coder}
  end

  def create(index, transaction, new_record) do
    id = KeyExpression.fetch(index.key_expression, new_record)

    index.type.create(id)
    |> atomic(index, transaction, id)
  end

  def update(index, transaction, old_record, new_record) do
    new_id = KeyExpression.fetch(index.key_expression, new_record)
    old_id = KeyExpression.fetch(index.key_expression, old_record)

    index.type.update(new_id, old_id)
    |> atomic(index, transaction, new_id)
  end

  def delete(index, transaction, current_record) do
    id = KeyExpression.fetch(index.key_expression, current_record)

    index.type.delete(id)
    |> atomic(index, transaction, id)
  end

  def scan(index, database_or_transaction, key_selector_range) do
    Transaction.get_range(database_or_transaction, key_selector_range, %{coder: index.coder})
  end

  defp atomic(nil, _, _, _) do
    :ok
  end

  defp atomic({mutation_type, value}, index, transaction, key) do
    :ok = Transaction.atomic_op(transaction, key, mutation_type, value, %{coder: index.coder})
  end
end
