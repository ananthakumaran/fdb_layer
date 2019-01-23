defmodule FDBLayer.RecordTest do
  alias FDBLayer.Repo
  alias FDBLayer.Index
  alias FDB.Database
  alias Sample.Post
  alias FDB.KeySelectorRange

  use ExUnit.Case

  setup do
    TestUtils.flushdb()
  end

  test "crud" do
    db = TestUtils.new_database()

    Database.transact(db, fn t ->
      Repo.create(t, Post, %Blog.Post{id: "1234", title: "hello", user_id: "8"})
      Repo.create(t, Post, %Blog.Post{id: "5678", user_id: "8"})
    end)

    assert_raise FDBLayer.DuplicateRecordError, fn ->
      Database.transact(db, fn t ->
        Repo.create(t, Post, %Blog.Post{id: "1234"})
      end)
    end

    posts =
      Index.scan(Post.index("users_posts"), db, KeySelectorRange.starts_with({"8"}))
      |> Enum.to_list()

    assert posts == [{"8", "1234"}, {"8", "5678"}]

    Database.transact(db, fn t ->
      post = Repo.get(t, Post, "abcd")
      assert post == nil

      post = Repo.get(t, Post, "1234")
      assert post.title == "hello"

      Repo.delete(t, Post, post)

      post = Repo.get(t, Post, "5678")
      Repo.update(t, Post, %{post | title: "new"})
    end)

    Database.transact(db, fn t ->
      post = Repo.get(t, Post, "1234")
      assert post == nil

      post = Repo.get(t, Post, "5678")
      assert post.title == "new"
    end)
  end
end
