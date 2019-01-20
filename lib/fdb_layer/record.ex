defmodule FDBLayer.Record do
  @moduledoc """
  Refer modules named FDB.Coder.* for sample implementation.
  """
  @callback coder() :: FDB.Coder.t
  @callback primary_key() :: FDBLayer.KeyExpression.t


  defmacro __using__(_) do
    quote do
      @behaviour FDBLayer.Record
    end
  end

  defstruct [:coder, :primary_key]

  def new(impl) do
    primary_key = impl.primary_key()
    %__MODULE__{coder: FDB.Transaction.Coder.new(primary_key.coder(), impl.coder()), primary_key: primary_key}
  end
end
