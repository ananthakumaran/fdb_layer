defmodule FDBLayer.RecordTest do
  alias FDBLayer.Repo
  alias FDBLayer.Index
  alias FDB.Database
  alias Sample.Comment
  alias Sample.Post
  alias Sample.User
  alias FDB.KeySelectorRange
  alias FDBLayer.Store

  use ExUnit.Case, async: false

  setup do
    TestUtils.flushdb()
  end

  test "crud" do
    db = TestUtils.new_database()

    store =
      Database.transact(db, fn t ->
        Store.create(t, %{records: [Post, User], path: ["blog"]})
      end)

    post_record = Store.record(store, Post)
    user_record = Store.record(store, User)

    Database.transact(db, fn t ->
      Repo.create(t, post_record, %Post{
        id: "1234",
        title: "hello",
        user_id: "8",
        claps: 5,
        content: "hello"
      })

      Repo.create(t, post_record, %Post{id: "5678", user_id: "9", claps: 0, content: "hello"})

      Repo.create(t, post_record, %Post{
        id: "5679",
        user_id: "9",
        claps: 0,
        content: "hello",
        comments: [
          %Comment{id: "1", user_id: "8", content: "cool"},
          %Comment{id: "2", user_id: "8", content: "awesome"}
        ]
      })
    end)

    assert_raise FDBLayer.DuplicateRecordError, fn ->
      Database.transact(db, fn t ->
        Repo.create(t, post_record, %Post{id: "1234"})
      end)
    end

    posts =
      Index.scan(Store.index(store, Post, "users_posts"), db, KeySelectorRange.starts_with({"9"}))
      |> Stream.map(fn {key, ""} -> key end)
      |> Enum.to_list()

    assert posts == [{"9", "5678"}, {"9", "5679"}]

    comments =
      Index.scan(
        Store.index(store, Post, "users_comments"),
        db,
        KeySelectorRange.starts_with({"8"})
      )
      |> Enum.to_list()

    assert comments == [
             {{"8", "1"}, %Comment{content: "cool", id: "1", user_id: "8"}},
             {{"8", "2"}, %Comment{content: "awesome", id: "2", user_id: "8"}}
           ]

    Database.transact(db, fn t ->
      assert Index.Aggregate.fetch_one(Store.index(store, Post, "posts_count"), t) == 3
      assert Index.Aggregate.fetch_one(Store.index(store, Post, "users_posts_count"), t, "8") == 1
      assert Index.Aggregate.fetch_one(Store.index(store, Post, "users_posts_count"), t, "9") == 2
    end)

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
      assert Index.Aggregate.fetch_one(Store.index(store, Post, "posts_count"), t) == 2
      assert Index.Aggregate.fetch_one(Store.index(store, Post, "users_posts_count"), t, "8") == 0
      assert Index.Aggregate.fetch_one(Store.index(store, Post, "users_posts_count"), t, "9") == 2
    end)

    Database.transact(db, fn t ->
      post = Repo.get(t, post_record, "1234")
      assert post == nil

      post = Repo.get(t, post_record, "5678")
      assert post.title == "new"
    end)

    Database.transact(db, fn t ->
      Repo.create(t, user_record, %User{id: "1", name: "john"})
      Repo.create(t, user_record, %User{id: "2", name: "wick"})
    end)

    Database.transact(db, fn t ->
      user = Repo.get(t, user_record, "1")
      assert user.name == "john"

      user = Repo.get(t, user_record, "2")
      assert user.name == "wick"
    end)
  end
end
