defmodule Sample.User do
  use FDBLayer.Record
  alias FDBLayer.{KeyExpression, Index}
  alias FDB.Coder.ByteString
  alias FDBLayer.Coder.Proto
  use Protobuf, from: Path.join(__DIR__, "blog.proto"), only: [:User], inject: true

  @impl true
  def primary_index do
    Index.Primary.new(%{
      path: ["record", "users"],
      name: "users",
      key_expression: KeyExpression.field(:id, %{coder: ByteString.new()}),
      value_coder: Proto.new(__MODULE__)
    })
  end
end
