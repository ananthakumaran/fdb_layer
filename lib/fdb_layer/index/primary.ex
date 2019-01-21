defmodule FDBLayer.Index.Primary do
  alias FDB.Transaction
  @enforce_keys [:name, :key_expression, :value_coder]
  defstruct [:name, :key_expression, :value_coder, :coder]

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
    Transaction.get(transaction, id, %{coder: index.coder})
  end
end

defimpl FDBLayer.Index, for: FDBLayer.Index.Primary do
  alias FDB.Transaction
  alias FDBLayer.KeyExpression

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
end
