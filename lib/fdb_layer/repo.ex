defmodule FDBLayer.Repo do
  alias FDBLayer.KeyExpression
  alias FDBLayer.Index
  alias FDBLayer.Index.Primary
  alias FDBLayer.Record

  def create(transaction, mod, value) do
    record = Record.fetch(mod)
    id = KeyExpression.fetch(record.primary_index.key_expression, value)
    current = Primary.fetch_one(record.primary_index, transaction, id)

    if current do
      raise FDBLayer.DuplicateRecordError, """
      A record with primary key `#{id}` already exists.
      Existing Record: #{inspect(current)}
      """
    end

    Enum.each([record.primary_index] ++ record.indices, &Index.create(&1, transaction, value))
  end

  def get(transaction, mod, id) do
    get_q(transaction, mod, id)
    |> FDB.Future.await()
  end

  def get_q(transaction, mod, id) do
    record = Record.fetch(mod)
    Primary.fetch_one_q(record.primary_index, transaction, id)
  end

  def update(transaction, mod, value) do
    record = Record.fetch(mod)
    id = KeyExpression.fetch(record.primary_index.key_expression, value)
    current = Primary.fetch_one(record.primary_index, transaction, id)

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
    record = Record.fetch(mod)
    id = KeyExpression.fetch(record.primary_index.key_expression, value)
    current = Primary.fetch_one(record.primary_index, transaction, id)

    if current do
      Enum.each([record.primary_index] ++ record.indices, &Index.delete(&1, transaction, current))
      true
    else
      false
    end
  end

  def execute() do
  end
end
