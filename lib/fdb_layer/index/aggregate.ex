defmodule FDBLayer.Index.Aggregate do
  alias FDB.Transaction
  alias FDBLayer.KeyExpression

  @enforce_keys [:name, :path, :type]
  defstruct [:name, :path, :group_expression, :value_expression, :type, :coder]

  def new(opts) do
    opts =
      Map.update(opts, :value_expression, KeyExpression.empty(), & &1)
      |> Map.update(:group_expression, KeyExpression.empty(), & &1)

    opts =
      Map.put(
        opts,
        :coder,
        FDB.Transaction.Coder.new(opts.group_expression.coder, opts.type.coder())
      )

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
  alias FDBLayer.KeyExpression

  def init(index, transaction, root_directory) do
    directory = FDB.Directory.create_or_open(root_directory, transaction, index.path)
    coder = Map.update!(index.coder, :key, &FDB.Coder.Subspace.new(directory, &1))
    %{index | coder: coder}
  end

  def create(index, transaction, new_record) do
    id = KeyExpression.fetch(index.group_expression, new_record)
    value = KeyExpression.fetch(index.value_expression, new_record)

    index.type.create(value)
    |> atomic(index, transaction, id)
  end

  def update(index, transaction, old_record, new_record) do
    new_id = KeyExpression.fetch(index.group_expression, new_record)
    old_id = KeyExpression.fetch(index.group_expression, old_record)

    new_value = KeyExpression.fetch(index.value_expression, new_record)
    old_value = KeyExpression.fetch(index.value_expression, old_record)

    if new_id == old_id do
      index.type.update(old_value, new_value)
      |> atomic(index, transaction, new_id)
    else
      index.type.delete(old_value)
      |> atomic(index, transaction, old_id)

      index.type.create(new_value)
      |> atomic(index, transaction, new_id)
    end
  end

  def delete(index, transaction, current_record) do
    id = KeyExpression.fetch(index.group_expression, current_record)
    value = KeyExpression.fetch(index.value_expression, current_record)

    index.type.delete(value)
    |> atomic(index, transaction, id)
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
