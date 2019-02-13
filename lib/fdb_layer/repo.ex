defmodule FDBLayer.Repo do
  alias FDBLayer.Index.Primary
  alias FDBLayer.Index
  alias FDBLayer.Projection
  alias FDB.Future

  def create(transaction, record, value) do
    create_q(transaction, record, value)
    |> Future.map(fn _ -> :ok end)
    |> Future.await()
  end

  def create_q(transaction, record, value) do
    Enum.map([record.primary_index] ++ record.indices, &Index.create(&1, transaction, value))
    |> Future.all()
  end

  def get(transaction, record, id) do
    get_q(transaction, record, id)
    |> FDB.Future.await()
  end

  def get_q(transaction, record, id) do
    Primary.fetch_one_q(record.primary_index, transaction, id)
  end

  def update(transaction, record, value) do
    update_q(transaction, record, value)
    |> Future.map(fn _ -> :ok end)
    |> Future.await()
  end

  def update_q(transaction, record, value) do
    key = Projection.key(record.primary_index.projection, value)

    Primary.fetch_one_q(record.primary_index, transaction, key)
    |> Future.then(fn current ->
      unless current do
        raise FDBLayer.RecordNotFoundError, """
        A record with primary key `#{key}` does not exist.
        """
      end

      Enum.map(
        [record.primary_index] ++ record.indices,
        &Index.update(&1, transaction, current, value)
      )
      |> Future.all()
    end)
  end

  def delete(transaction, record, value) do
    delete_q(transaction, record, value)
    |> Future.await()
  end

  def delete_q(transaction, record, value) do
    key = Projection.key(record.primary_index.projection, value)

    Primary.fetch_one_q(record.primary_index, transaction, key)
    |> Future.then(fn current ->
      if current do
        Enum.map(
          [record.primary_index] ++ record.indices,
          &Index.delete(&1, transaction, current)
        )
        |> Future.all()
        |> Future.map(fn _ -> true end)
      else
        false
      end
    end)
  end

  def execute() do
  end
end
