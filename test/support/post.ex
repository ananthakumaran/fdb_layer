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
    Index.Primary.new(%{
      name: "posts",
      key_expression: KeyExpression.field(%{field: :id, coder: ByteString.new()}),
      value_coder: Proto.new(Blog.Post)
    })
  end

  @impl true
  def indices do
    [
      Index.Value.new(%{
        name: "users_posts",
        key_expression:
          KeyExpression.concat(
            KeyExpression.field(%{field: :user_id, coder: ByteString.new()}),
            KeyExpression.field(%{field: :id, coder: ByteString.new()})
          )
      })
    ]
  end
end
