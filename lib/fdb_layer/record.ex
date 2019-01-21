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

  defstruct [:primary_index, :indices]

  def new(impl) do
    %__MODULE__{
      primary_index: impl.primary_index(),
      indices: impl.indices()
    }
  end
end
