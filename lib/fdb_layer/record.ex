defmodule FDBLayer.Record do
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

      def index(name) do
        record = FDBLayer.Record.fetch(__MODULE__)
        record.indices_by_name[name]
      end

      defoverridable FDBLayer.Record
    end
  end

  defstruct [:primary_index, :indices, :indices_by_name]

  def new(impl) do
    primary_index = impl.primary_index()
    indices = impl.indices()

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

  def fetch(mod) do
    key = {__MODULE__, mod}

    try do
      :persistent_term.get(key)
    rescue
      ArgumentError ->
        record = FDBLayer.Record.new(mod)
        :ok = :persistent_term.put(key, FDBLayer.Record.new(mod))
        record
    end
  end
end
