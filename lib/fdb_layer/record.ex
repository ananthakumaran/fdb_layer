defmodule FDBLayer.Record do
  @moduledoc """
  Refer modules named FDB.Coder.* for sample implementation.
  """
  @callback coder() :: FDB.Coder.t()
  @callback primary_index() :: FDBLayer.KeyExpression.t()
  @callback indices() :: [FDBLayer.Index.t()]

  defmacro __using__(_) do
    quote do
      @behaviour FDBLayer.Record

      @impl true
      def indices(), do: []

      defoverridable FDBLayer.Record
    end
  end

  defstruct [:coder, :primary_index, :indices]

  def new(impl) do
    primary_index = impl.primary_index()

    %__MODULE__{
      coder: FDB.Transaction.Coder.new(primary_index.key_expression.coder, impl.coder()),
      primary_index: primary_index,
      indices: impl.indices()
    }
  end
end
