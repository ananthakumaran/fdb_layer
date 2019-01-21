defmodule FDBLayer.RecordTest do
  alias FDBLayer.Repo
  alias FDB.Database
  alias Sample.Post

  use ExUnit.Case

  setup do
    TestUtils.flushdb()
  end

  test "crud" do
    db = TestUtils.new_database()

    Database.transact(db, fn t ->
      Repo.create(t, Post, %Blog.Post{id: "1234", title: "hello", user_id: "1"})
      Repo.create(t, Post, %Blog.Post{id: "5678", user_id: "1"})
    end)

    assert_raise FDBLayer.DuplicateRecordError, fn ->
      Database.transact(db, fn t ->
        Repo.create(t, Post, %Blog.Post{id: "1234"})
      end)
    end

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
