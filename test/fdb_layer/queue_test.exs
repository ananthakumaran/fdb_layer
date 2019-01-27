defmodule FDBLayer.QueueTest do
  alias FDBLayer.Queue
  alias FDB.Coder
  alias FDB.Database

  use ExUnit.Case, async: false

  setup do
    TestUtils.flushdb()
  end

  test "queue" do
    queue = Queue.new(%{subspace: Coder.Subspace.new("q")})
    db = TestUtils.new_database()

    size =
      Database.transact(db, fn t ->
        Queue.size(queue, t)
      end)

    assert size == 0

    Database.transact(db, fn t ->
      :ok = Queue.enqueue(queue, t, 1, %{order: 0})
      :ok = Queue.enqueue(queue, t, 2, %{order: 1})
    end)

    Database.transact(db, fn t ->
      :ok = Queue.enqueue(queue, t, 3)
    end)

    size =
      Database.transact(db, fn t ->
        Queue.size(queue, t)
      end)

    assert size == 3

    item =
      Database.transact(db, fn t ->
        Queue.dequeue(queue, t)
      end)

    assert item == 1

    size =
      Database.transact(db, fn t ->
        Queue.size(queue, t)
      end)

    assert size == 2

    item =
      Database.transact(db, fn t ->
        Queue.dequeue(queue, t)
      end)

    assert item == 2

    size =
      Database.transact(db, fn t ->
        Queue.size(queue, t)
      end)

    assert size == 1

    item =
      Database.transact(db, fn t ->
        Queue.dequeue(queue, t)
      end)

    assert item == 3

    size =
      Database.transact(db, fn t ->
        Queue.size(queue, t)
      end)

    assert size == 0

    item =
      Database.transact(db, fn t ->
        Queue.dequeue(queue, t)
      end)

    assert item == nil

    size =
      Database.transact(db, fn t ->
        Queue.size(queue, t)
      end)

    assert size == 0
  end
end
