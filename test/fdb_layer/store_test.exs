defmodule FDBLayer.StoreTest do
  alias FDB.Database
  alias Sample.Post
  alias FDBLayer.Store
  alias FDB.Directory
  alias FDB.KeySelectorRange
  alias FDBLayer.Repo
  alias FDBLayer.Index

  use ExUnit.Case

  setup do
    TestUtils.flushdb()
  end

  test "global store" do
    db = TestUtils.new_database()

    Database.transact(db, fn t ->
      Store.create(t, %{records: [Post], path: ["blog"]})
    end)

    root = Directory.new()

    Database.transact(db, fn t ->
      assert TestUtils.tree(root, t) == %{
               "blog" => %{
                 "record" => %{"posts" => %{}},
                 "index" => %{
                   "posts" => %{"count" => %{}},
                   "users" => %{"post_id" => %{}, "posts_count" => %{}}
                 }
               }
             }
    end)
  end

  test "per user store" do
    db = TestUtils.new_database()

    user_1 =
      Database.transact(db, fn t ->
        Store.create(t, %{records: [Post], path: ["user", "1"]})
      end)

    user_2 =
      Database.transact(db, fn t ->
        Store.create(t, %{records: [Post], path: ["user", "2"]})
      end)

    root = Directory.new()

    Database.transact(db, fn t ->
      assert TestUtils.tree(root, t) == %{
               "user" => %{
                 "1" => %{
                   "record" => %{"posts" => %{}},
                   "index" => %{
                     "posts" => %{"count" => %{}},
                     "users" => %{"post_id" => %{}, "posts_count" => %{}}
                   }
                 },
                 "2" => %{
                   "record" => %{"posts" => %{}},
                   "index" => %{
                     "posts" => %{"count" => %{}},
                     "users" => %{"post_id" => %{}, "posts_count" => %{}}
                   }
                 }
               }
             }
    end)

    Database.transact(db, fn t ->
      Repo.create(t, Store.record(user_1, Post), %Blog.Post{
        id: "1234",
        title: "hello",
        user_id: "1"
      })

      Repo.create(t, Store.record(user_2, Post), %Blog.Post{id: "5678", user_id: "2"})
    end)

    posts =
      Index.scan(Store.index(user_1, Post, "users_posts"), db, KeySelectorRange.starts_with({}))
      |> Enum.to_list()

    assert posts == [{"1", "1234"}]

    posts =
      Index.scan(Store.index(user_2, Post, "users_posts"), db, KeySelectorRange.starts_with({}))
      |> Enum.to_list()

    assert posts == [{"2", "5678"}]

    Database.transact(db, fn t ->
      Store.delete(user_1, t)
    end)

    posts =
      Index.scan(Store.index(user_1, Post, "users_posts"), db, KeySelectorRange.starts_with({}))
      |> Enum.to_list()

    assert posts == []

    posts =
      Index.scan(Store.index(user_2, Post, "users_posts"), db, KeySelectorRange.starts_with({}))
      |> Enum.to_list()

    assert posts == [{"2", "5678"}]

    Database.transact(db, fn t ->
      assert TestUtils.tree(root, t) == %{
               "user" => %{
                 "2" => %{
                   "index" => %{
                     "posts" => %{"count" => %{}},
                     "users" => %{"post_id" => %{}, "posts_count" => %{}}
                   },
                   "record" => %{"posts" => %{}}
                 }
               }
             }
    end)
  end
end
