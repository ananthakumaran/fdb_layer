defmodule FDBLayer.RecordTest do
  alias FDBLayer.Repo
  alias FDB.Database

  use ExUnit.Case

  setup do
    TestUtils.flushdb()
  end

  test "crud" do
    db = TestUtils.new_database()

    Database.transact(db, fn t ->
      Repo.create(t, Sample.Post, %Blog.Post{id: "1234", title: "hello"})
      Repo.create(t, Sample.Post, %Blog.Post{id: "5678"})
    end)

    post =
      Database.transact(db, fn t ->
        Repo.get(t, Sample.Post, "1234")
      end)

    assert post.title == "hello"
  end
end
