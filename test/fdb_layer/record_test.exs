defmodule FDBLayer.RecordTest do
  alias FDBLayer.Repo
  alias FDBLayer.Index
  alias FDB.Database
  alias Sample.Post
  alias FDB.KeySelectorRange
  alias FDBLayer.Store

  use ExUnit.Case

  setup do
    TestUtils.flushdb()
  end

  test "crud" do
    db = TestUtils.new_database()

    store =
      Database.transact(db, fn t ->
        Store.create(t, %{records: [Post], path: ["blog"]})
      end)

    post_record = Store.record(store, Post)

    Database.transact(db, fn t ->
      Repo.create(t, post_record, %Blog.Post{id: "1234", title: "hello", user_id: "8"})
      Repo.create(t, post_record, %Blog.Post{id: "5678", user_id: "8"})
    end)

    assert_raise FDBLayer.DuplicateRecordError, fn ->
      Database.transact(db, fn t ->
        Repo.create(t, post_record, %Blog.Post{id: "1234"})
      end)
    end

    posts =
      Index.scan(Store.index(store, Post, "users_posts"), db, KeySelectorRange.starts_with({"8"}))
      |> Enum.to_list()

    assert posts == [{"8", "1234"}, {"8", "5678"}]

    Database.transact(db, fn t ->
      post = Repo.get(t, post_record, "abcd")
      assert post == nil

      post = Repo.get(t, post_record, "1234")
      assert post.title == "hello"

      Repo.delete(t, post_record, post)

      post = Repo.get(t, post_record, "5678")
      Repo.update(t, post_record, %{post | title: "new"})
    end)

    Database.transact(db, fn t ->
      post = Repo.get(t, post_record, "1234")
      assert post == nil

      post = Repo.get(t, post_record, "5678")
      assert post.title == "new"
    end)
  end
end
