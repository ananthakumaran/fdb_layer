defmodule FDBLayer.Index do
  alias FDB.Transaction
  alias FDBLayer.KeyExpression

  @enforce_keys [:name, :key_expression, :type]
  defstruct [:name, :key_expression, :type, :value_coder, :coder]

  def new(opts) do
    value_coder = Map.get(opts, :value_coder)

    opts =
      if value_coder do
        Map.put(
          opts,
          :coder,
          FDB.Transaction.Coder.new(opts.key_expression.coder, value_coder)
        )
      else
        opts
      end

    struct!(__MODULE__, opts)
  end

  def fetch_one(%__MODULE__{type: :primary} = index, transaction, id) do
    Transaction.get(transaction, id, %{coder: index.coder})
  end

  def create(%__MODULE__{type: :primary} = index, transaction, new_record) do
    id = KeyExpression.fetch(index.key_expression, new_record)
    :ok = Transaction.set(transaction, id, new_record, %{coder: index.coder})
  end

  def update(%__MODULE__{type: :primary} = index, transaction, _old_record, new_record) do
    id = KeyExpression.fetch(index.key_expression, new_record)
    :ok = Transaction.set(transaction, id, new_record, %{coder: index.coder})
  end

  def delete(%__MODULE__{type: :primary} = index, transaction, current_record) do
    id = KeyExpression.fetch(index.key_expression, current_record)
    :ok = Transaction.clear(transaction, id, %{coder: index.coder})
  end
end
