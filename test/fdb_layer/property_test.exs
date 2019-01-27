defmodule FDBLayer.PropertyTest do
  alias FDBLayer.Repo
  alias FDBLayer.Index
  alias FDB.Database
  alias Sample.Post
  alias FDB.KeySelectorRange
  alias FDBLayer.Store
  use ExUnitProperties

  use ExUnit.Case, async: false

  setup do
    TestUtils.flushdb()
  end

  @record_count 1000
  @records (for i <- 1..@record_count do
              %Blog.Post{id: "post_#{i}", user_id: "user_#{Integer.mod(i, 10) + 1}"}
            end)

  def gen_command() do
    one_of([
      {:create, member_of(@records)},
      {:update,
       map({member_of(@records), string(:ascii)}, fn {record, content} ->
         %{record | content: content}
       end)},
      {:delete, member_of(@records)}
    ])
  end

  def apply_commands(db, store, commands) do
    for command <- commands do
      Database.transact(db, fn t ->
        apply_command(t, store, command)
      end)
    end
  end

  def apply_command(transaction, store, {:create, record}) do
    Repo.create(transaction, Store.record(store, Post), record)
  rescue
    FDBLayer.DuplicateRecordError -> :ok
  end

  def apply_command(transaction, store, {:delete, record}) do
    Repo.delete(transaction, Store.record(store, Post), record)
  end

  def apply_command(transaction, store, {:update, record}) do
    Repo.update(transaction, Store.record(store, Post), record)
  rescue
    FDBLayer.RecordNotFoundError -> :ok
  end

  def verify_value_index(db, store) do
    actual =
      Index.scan(Store.index(store, Post, "users_posts"), db, KeySelectorRange.starts_with({}))
      |> Enum.to_list()

    expected =
      Index.scan(Store.index(store, Post, "posts"), db, KeySelectorRange.starts_with(nil))
      |> Enum.map(fn {id, record} ->
        {record.user_id, id}
      end)
      |> Enum.sort()

    assert actual == expected
  end

  def verify_global_count_index(db, store) do
    actual =
      Database.transact(db, fn t ->
        Index.Aggregate.fetch_one(Store.index(store, Post, "posts_count"), t)
      end)

    expected =
      Index.scan(Store.index(store, Post, "posts"), db, KeySelectorRange.starts_with(nil))
      |> Enum.count()

    assert actual == expected
  end

  def verify_user_count_index(db, store) do
    actual =
      Index.scan(
        Store.index(store, Post, "users_posts_count"),
        db,
        KeySelectorRange.starts_with(nil)
      )
      |> Enum.to_list()

    expected =
      Index.scan(Store.index(store, Post, "posts"), db, KeySelectorRange.starts_with(nil))
      |> Enum.map(fn {id, record} ->
        {record.user_id, id}
      end)
      |> Enum.group_by(fn {user_id, _id} -> user_id end)
      |> Enum.map(fn {user_id, values} -> {user_id, Enum.count(values)} end)
      |> Enum.sort()

    assert actual == expected
  end

  property "consistency" do
    db = TestUtils.new_database()

    store =
      Database.transact(db, fn t ->
        Store.create(t, %{records: [Post], path: ["blog"]})
      end)

    check all commands <- list_of(gen_command()) do
      apply_commands(db, store, commands)
      verify_value_index(db, store)
      verify_global_count_index(db, store)
      verify_user_count_index(db, store)
    end
  end
end
