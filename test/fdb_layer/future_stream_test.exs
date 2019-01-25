defmodule FDBLayer.StreamTest do
  alias FDBLayer.Repo
  alias FDBLayer.Index
  alias FDB.Database
  alias Sample.Post
  alias FDBLayer.FutureStream
  alias FDB.KeySelectorRange

  use ExUnit.Case

  setup do
    TestUtils.flushdb()
  end

  test "concurrent_map" do
    db = TestUtils.new_database()
    size = 10000

    Stream.chunk_every(1..size, 100)
    |> Stream.each(fn chunk ->
      Database.transact(db, fn t ->
        Enum.each(chunk, fn i ->
          Repo.create(t, Post, %Blog.Post{id: "post_#{i}", title: "hello", user_id: "user_#{i}"})
        end)
      end)
    end)
    |> Stream.run()

    posts =
      Database.transact(db, fn t ->
        Index.scan(Post.index("users_posts"), t, KeySelectorRange.starts_with({"user_"}))
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
