defmodule Sample.Post do
  use FDBLayer.Record
  alias FDBLayer.{KeyExpression, Index}
  alias FDB.Coder.ByteString
  alias FDBLayer.Coder.Proto
  use Protobuf, from: Path.join(__DIR__, "blog.proto"), only: [:Post], inject: true

  @impl true
  def primary_index do
    Index.Primary.new(%{
      path: ["record", "posts"],
      name: "posts",
      key_expression: KeyExpression.field(:id, %{coder: ByteString.new()}),
      value_coder: Proto.new(__MODULE__)
    })
  end

  @impl true
  def indices do
    [
      Index.Value.new(%{
        name: "users_posts",
        path: ["index", "users", "post_id"],
        key_expression:
          KeyExpression.concat(
            KeyExpression.field(:user_id, %{coder: ByteString.new()}),
            KeyExpression.field(:id, %{coder: ByteString.new()})
          )
      }),
      Index.Aggregate.new(%{
        name: "posts_count",
        path: ["index", "posts", "count"],
        type: Index.Aggregate.Count
      }),
      Index.Aggregate.new(%{
        name: "users_posts_count",
        path: ["index", "users", "posts_count"],
        type: Index.Aggregate.Count,
        group_expression: KeyExpression.field(:user_id, %{coder: ByteString.new()})
      }),
      Index.Aggregate.new(%{
        name: "users_claps_sum",
        path: ["index", "users", "claps_sum"],
        type: Index.Aggregate.Sum,
        group_expression: KeyExpression.field(:user_id, %{coder: ByteString.new()}),
        value_expression: KeyExpression.field(:claps)
      })
    ]
  end
end
