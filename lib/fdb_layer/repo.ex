defmodule FDBLayer.Repo do
  alias FDBLayer.KeyExpression
  alias FDBLayer.Index
  alias FDBLayer.Index.Primary

  def create(transaction, record, value) do
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

  def get(transaction, record, id) do
    get_q(transaction, record, id)
    |> FDB.Future.await()
  end

  def get_q(transaction, record, id) do
    Primary.fetch_one_q(record.primary_index, transaction, id)
  end

  def update(transaction, record, value) do
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

  def delete(transaction, record, value) do
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
