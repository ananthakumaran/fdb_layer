defmodule FDBLayer.Repo do
  alias FDBLayer.KeyExpression
  alias FDBLayer.Index

  def create(transaction, mod, value) do
    record = fetch_record(mod)
    id = KeyExpression.fetch(record.primary_index.key_expression, value)
    current = Index.fetch_one(record.primary_index, transaction, id)

    if current do
      raise FDBLayer.DuplicateRecordError, """
      A record with primary key `#{id}` already exists.
      Existing Record: #{inspect(current)}
      """
    end

    Enum.each([record.primary_index] ++ record.indices, &Index.create(&1, transaction, value))
  end

  def get(transaction, mod, id) do
    record = fetch_record(mod)
    Index.fetch_one(record.primary_index, transaction, id)
  end

  def update(transaction, mod, value) do
    record = fetch_record(mod)
    id = KeyExpression.fetch(record.primary_index.key_expression, value)
    current = Index.fetch_one(record.primary_index, transaction, id)

    unless current do
      raise FDBLayer.RecordNotFoundError, """
      A record with primary key `#{id}` does not exist.
      """
    end

    Enum.each(
      [record.primary_index] ++ record.indices,
      &Index.update(&1, transaction, current, value)
    )
  end

  def delete(transaction, mod, value) do
    record = fetch_record(mod)
    id = KeyExpression.fetch(record.primary_index.key_expression, value)
    current = Index.fetch_one(record.primary_index, transaction, id)

    if current do
      Enum.each([record.primary_index] ++ record.indices, &Index.delete(&1, transaction, current))
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
