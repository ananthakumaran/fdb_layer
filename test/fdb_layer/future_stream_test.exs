defmodule FDBLayer.StreamTest do
  alias FDBLayer.Repo
  alias FDBLayer.Index
  alias FDB.Database
  alias Sample.Post
  alias FDBLayer.FutureStream
  alias FDB.KeySelectorRange
  alias FDBLayer.Store

  use ExUnit.Case

  setup do
    TestUtils.flushdb()
  end

  test "concurrent_map" do
    db = TestUtils.new_database()
    size = 10000

    store =
      Database.transact(db, fn t ->
        Store.create(t, %{records: [Post], path: ["blog"]})
      end)

    Stream.chunk_every(1..size, 100)
    |> Stream.each(fn chunk ->
      Database.transact(db, fn t ->
        Enum.each(chunk, fn i ->
          Repo.create(t, Store.record(store, Post), %Blog.Post{
            id: "post_#{i}",
            title: "hello",
            user_id: "user_#{i}"
          })
        end)
      end)
    end)
    |> Stream.run()

    posts =
      Database.transact(db, fn t ->
        Index.scan(
          Store.index(store, Post, "users_posts"),
          t,
          KeySelectorRange.starts_with({})
        )
        |> FutureStream.map(
          fn {_user_id, post_id} ->
            Repo.get_q(t, Post, post_id)
          end,
          %{concurrency: 30}
        )
        |> Enum.to_list()
      end)

    assert length(posts) == size
  end
end
