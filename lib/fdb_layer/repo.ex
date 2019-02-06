defmodule FDBLayer.Repo do
  alias FDBLayer.Index.Primary
  alias FDBLayer.Index
  alias FDBLayer.Projection

  def create(transaction, record, value) do
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
    key = Projection.key(record.primary_index.projection, value)
    current = Primary.fetch_one(record.primary_index, transaction, key)

    unless current do
      raise FDBLayer.RecordNotFoundError, """
      A record with primary key `#{key}` does not exist.
      """
    end

    Enum.each(
      [record.primary_index] ++ record.indices,
      &Index.update(&1, transaction, current, value)
    )
  end

  def delete(transaction, record, value) do
    key = Projection.key(record.primary_index.projection, value)
    current = Primary.fetch_one(record.primary_index, transaction, key)

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
