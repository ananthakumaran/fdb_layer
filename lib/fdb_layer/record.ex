defmodule FDBLayer.Record do
  alias FDBLayer.Index

  @moduledoc """
  Refer modules named FDB.Coder.* for sample implementation.
  """
  @callback coder() :: FDB.Coder.t()
  @callback primary_index() :: FDBLayer.Index.t()
  @callback indices() :: [FDBLayer.Index.t()]

  defmacro __using__(_) do
    quote do
      @behaviour FDBLayer.Record

      @impl true
      def indices(), do: []

      defoverridable FDBLayer.Record
    end
  end

  defstruct [:primary_index, :indices, :indices_by_name]

  def new(transaction, root_directory, impl) do
    primary_index =
      impl.primary_index()
      |> Index.init(transaction, root_directory)

    indices =
      impl.indices()
      |> Enum.map(&Index.init(&1, transaction, root_directory))

    %__MODULE__{
      primary_index: primary_index,
      indices: indices,
      indices_by_name:
        Enum.map([primary_index] ++ indices, fn index ->
          {index.name, index}
        end)
        |> Enum.into(%{})
    }
  end
end
