defmodule Sample.Post do
  use FDBLayer.Record

  @impl true
  def coder do
    FDBLayer.Coder.Proto.new(Blog.Post)
  end

  @impl true
  def primary_key do
    FDBLayer.KeyExpression.field(%{field: :id, coder: FDB.Coder.ByteString.new()})
  end
end
