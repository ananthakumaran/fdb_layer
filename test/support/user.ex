defmodule Sample.User do
  use FDBLayer.Record
  alias FDBLayer.{Projection, Index}
  alias FDB.Coder.ByteString
  alias FDBLayer.Coder.Avro
  alias FDB.Transaction

  @schema %{
    namespace: "sample",
    type: "record",
    name: "User",
    fields: [
      %{name: "id", type: "string"},
      %{name: "name", type: "string"}
    ]
  }

  @impl true
  def primary_index do
    Index.Primary.new(%{
      path: ["record", "users"],
      name: "users",
      coder: Transaction.Coder.new(ByteString.new(), Avro.new(@schema)),
      projection: Projection.new(fn u -> {u.id, u} end)
    })
  end
end
