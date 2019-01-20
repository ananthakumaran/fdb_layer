defmodule Sample.Post do
  use FDBLayer.Record
  alias FDBLayer.{KeyExpression, Index}
  alias FDB.Coder.ByteString
  alias FDBLayer.Coder.Proto

  @impl true
  def coder do
    Proto.new(Blog.Post)
  end

  @impl true
  def primary_index do
    Index.new("posts", :primary, KeyExpression.field(%{field: :id, coder: ByteString.new()}))
  end

  @impl true
  def indices do
    [
      Index.new(
        "users_posts",
        :value,
        KeyExpression.field(%{field: :user_id, coder: ByteString.new()})
      )
    ]
  end
end
