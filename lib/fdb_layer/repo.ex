defmodule FDBLayer.Repo do
  alias FDB.Transaction
  alias FDBLayer.KeyExpression
  alias FDBLayer.Index

  def create(transaction, mod, value) do
    record = fetch_record(mod)
    id = KeyExpression.fetch(record.primary_index.key_expression, value)
    current = Transaction.get(transaction, id, %{coder: record.coder})

    if current do
      raise FDBLayer.DuplicateRecordError, """
      A record with primary key `#{id}` already exists.
      Existing Record: #{inspect(current)}
      """
    end

    Enum.each(record.indices, &Index.create(&1, value))
    :ok = Transaction.set(transaction, id, value, %{coder: record.coder})
  end

  def get(transaction, mod, id) do
    record = fetch_record(mod)
    Transaction.get(transaction, id, %{coder: record.coder})
  end

  def update(transaction, mod, value) do
    record = fetch_record(mod)
    id = KeyExpression.fetch(record.primary_index.key_expression, value)
    current = Transaction.get(transaction, id, %{coder: record.coder})

    unless current do
      raise FDBLayer.RecordNotFoundError, """
      A record with primary key `#{id}` does not exist.
      """
    end

    Enum.each(record.indices, &Index.update(&1, current, value))
    :ok = Transaction.set(transaction, id, value, %{coder: record.coder})
  end

  def delete(transaction, mod, value) do
    record = fetch_record(mod)
    id = KeyExpression.fetch(record.primary_index.key_expression, value)
    current = Transaction.get(transaction, id, %{coder: record.coder})

    if current do
      Enum.each(record.indices, &Index.delete(&1, current))
      :ok = Transaction.clear(transaction, id, %{coder: record.coder})
      true
    else
      false
    end
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
