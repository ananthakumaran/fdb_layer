defmodule FDBLayer.Index.Value do
  @enforce_keys [:name, :key_expression]
  defstruct [:name, :key_expression, :coder]

  def new(opts) do
    opts =
      Map.put(
        opts,
        :coder,
        FDB.Transaction.Coder.new(opts.key_expression.coder, FDB.Coder.ByteString.new())
      )

    struct!(__MODULE__, opts)
  end
end

defimpl FDBLayer.Index.Protocol, for: FDBLayer.Index.Value do
  alias FDB.Transaction
  alias FDBLayer.KeyExpression

  def create(index, transaction, new_record) do
    id = KeyExpression.fetch(index.key_expression, new_record)
    :ok = Transaction.set(transaction, id, "", %{coder: index.coder})
  end

  def update(index, transaction, old_record, new_record) do
    new_id = KeyExpression.fetch(index.key_expression, new_record)
    old_id = KeyExpression.fetch(index.key_expression, old_record)

    if new_id != old_id do
      :ok = Transaction.clear(transaction, old_id, %{coder: index.coder})
      :ok = Transaction.set(transaction, new_id, "", %{coder: index.coder})
    else
      :ok
    end
  end

  def delete(index, transaction, current_record) do
    id = KeyExpression.fetch(index.key_expression, current_record)
    :ok = Transaction.clear(transaction, id, %{coder: index.coder})
  end

  def scan(index, database_or_transaction, key_selector_range) do
    Transaction.get_range(database_or_transaction, key_selector_range, %{coder: index.coder})
    |> Stream.map(fn {key, ""} -> key end)
  end
end
