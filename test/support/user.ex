defmodule Sample.User do
  use FDBLayer.Record
  alias FDBLayer.{Projection, Index}
  alias FDB.Coder.ByteString
  alias FDBLayer.Coder.Proto
  alias FDB.Transaction
  use Protobuf, from: Path.join(__DIR__, "blog.proto"), only: [:User], inject: true

  @impl true
  def primary_index do
    Index.Primary.new(%{
      path: ["record", "users"],
      name: "users",
      coder: Transaction.Coder.new(ByteString.new(), Proto.new(__MODULE__)),
      projection: Projection.new(fn u -> {u.id, u} end)
    })
  end
end
