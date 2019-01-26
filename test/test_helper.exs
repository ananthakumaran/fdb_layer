:ok = FDB.start(600)
ExUnit.start()

defmodule TestUtils do
  alias FDB.Database
  alias FDB.Cluster
  alias FDB.Transaction
  alias FDB.KeyRange
  alias FDB.Directory

  def flushdb do
    t = new_transaction()

    :ok =
      Transaction.clear_range(
        t,
        KeyRange.range("", <<0xFF>>)
      )

    :ok = Transaction.commit(t)
  end

  def new_transaction do
    Cluster.create()
    |> Database.create()
    |> Transaction.create()
  end

  def new_database do
    Cluster.create()
    |> Database.create()
  end

  def tree(root, transaction) do
    dirs = Directory.list(root, transaction)

    for dir <- dirs, into: %{} do
      {dir, tree(Directory.open(root, transaction, [dir]), transaction)}
    end
  end
end
