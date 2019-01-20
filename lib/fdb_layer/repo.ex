defmodule FDBLayer.Repo do
  alias FDB.Transaction
  alias FDBLayer.KeyExpression

  def create(transaction, mod, value) do
    record = fetch_record(mod)
    id = KeyExpression.fetch(record.primary_key, value)
    :ok = Transaction.set(transaction, id, value, %{coder: record.coder})
  end

  def get(transaction, mod, id) do
    record = fetch_record(mod)
    Transaction.get(transaction, id, %{coder: record.coder})
  end

  def update(transaction, mod, value) do
    record = fetch_record(mod)
    id = KeyExpression.fetch(record.primary_key, value)
    :ok = Transaction.set(transaction, id, value, %{coder: record.coder})
  end

  def delete(transaction, mod, value) do
    record = fetch_record(mod)
    id = KeyExpression.fetch(record.primary_key, value)
    :ok = Transaction.clear(transaction, id, %{coder: record.coder})
  end

  def execute() do
  end

  defp fetch_record(mod) do
    key = {__MODULE__, mod}

    try do
      :persistent_term.get(key)
    rescue
      ArgumentError ->
        record = FDBLayer.Record.new(mod)
        :ok = :persistent_term.put(key, FDBLayer.Record.new(mod))
        record
    end
  end
end
