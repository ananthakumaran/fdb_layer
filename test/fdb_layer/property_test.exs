defmodule FDBLayer.PropertyTest do
  alias FDBLayer.Repo
  alias FDBLayer.Index
  alias FDB.Database
  alias Sample.Post
  alias Sample.Comment
  alias FDB.KeySelectorRange
  alias FDBLayer.Store
  use ExUnitProperties

  use ExUnit.Case, async: false

  setup do
    TestUtils.flushdb()
  end

  @record_count 1000
  @records (for i <- 1..@record_count do
              %Post{id: "post_#{i}", user_id: "user_#{Integer.mod(i, 10) + 1}"}
            end)

  def gen_comments(post_id) do
    list_of(
      map({string(:ascii), integer(1..10)}, fn {content, user_id} ->
        %Comment{content: content, user_id: "user_#{user_id}"}
      end),
      max_length: 5
    )
    |> map(fn comments ->
      Enum.with_index(comments)
      |> Enum.map(fn {c, i} -> %{c | id: "comment_#{post_id}_#{i}"} end)
    end)
  end

  def gen_record() do
    bind({member_of(@records), string(:ascii), integer(), integer(1..10)}, fn {record, content,
                                                                               claps, user_id} ->
      map(gen_comments(record.id), fn comments ->
        %{
          record
          | content: content,
            claps: claps,
            user_id: "user_#{user_id}",
            comments: comments
        }
      end)
    end)
  end

  def gen_command() do
    one_of([
      {:create, gen_record()},
      {:update, gen_record()},
      {:delete, member_of(@records)}
    ])
  end

  def apply_commands(db, store, commands) do
    for command <- commands do
      try do
        Database.transact(db, fn t ->
          apply_command(t, store, command)
        end)
      rescue
        FDBLayer.RecordNotFoundError -> :ok
        FDBLayer.DuplicateRecordError -> :ok
      end
    end
  end

  def apply_command(transaction, store, {:create, record}) do
    Repo.create(transaction, Store.record(store, Post), record)
  end

  def apply_command(transaction, store, {:delete, record}) do
    Repo.delete(transaction, Store.record(store, Post), record)
  end

  def apply_command(transaction, store, {:update, record}) do
    Repo.update(transaction, Store.record(store, Post), record)
  end

  def verify_value_index(db, store) do
    actual =
      Index.scan(Store.index(store, Post, "users_posts"), db, KeySelectorRange.starts_with({}))
      |> Stream.map(fn {key, ""} -> key end)
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
      |> Enum.filter(fn {_user_id, count} -> count != 0 end)

    expected =
      Index.scan(Store.index(store, Post, "posts"), db, KeySelectorRange.starts_with(nil))
      |> Enum.map(fn {id, record} ->
        {record.user_id, id}
      end)
      |> Enum.group_by(fn {user_id, _id} -> user_id end)
      |> Enum.map(fn {user_id, values} -> {user_id, Enum.count(values)} end)
      |> Enum.filter(fn {_user_id, count} -> count != 0 end)
      |> Enum.sort()

    assert actual == expected
  end

  def verify_user_claps_index(db, store) do
    actual =
      Index.scan(
        Store.index(store, Post, "users_claps_sum"),
        db,
        KeySelectorRange.starts_with(nil)
      )
      |> Enum.to_list()
      |> Enum.filter(fn {_user_id, count} -> count != 0 end)

    expected =
      Index.scan(Store.index(store, Post, "posts"), db, KeySelectorRange.starts_with(nil))
      |> Enum.map(fn {_id, record} ->
        {record.user_id, record.claps}
      end)
      |> Enum.group_by(fn {user_id, _claps} -> user_id end, fn {_user_id, claps} -> claps end)
      |> Enum.map(fn {user_id, claps} -> {user_id, Enum.sum(claps)} end)
      |> Enum.filter(fn {_user_id, count} -> count != 0 end)
      |> Enum.sort()

    assert actual == expected
  end

  def verify_user_comments_index(db, store) do
    actual =
      Index.scan(
        Store.index(store, Post, "users_comments"),
        db,
        KeySelectorRange.starts_with(nil)
      )
      |> Enum.to_list()

    expected =
      Index.scan(Store.index(store, Post, "posts"), db, KeySelectorRange.starts_with(nil))
      |> Enum.flat_map(fn {_id, record} ->
        record.comments
      end)
      |> Enum.map(fn comment -> {{comment.user_id, comment.id}, comment} end)
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
      verify_user_claps_index(db, store)
      verify_user_comments_index(db, store)
    end
  end
end
