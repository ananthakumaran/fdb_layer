defmodule FDBLayer.Store do
  alias FDB.Directory
  defstruct [:path, :root_directory, records: %{}]

  def create(transaction, %{records: records, path: path}) do
    root_directory =
      Directory.new()
      |> Directory.create_or_open(transaction, path, %{layer: "partition"})

    records =
      for record <- records, into: %{} do
        {record, FDBLayer.Record.new(transaction, root_directory, record)}
      end

    %__MODULE__{path: path, root_directory: root_directory, records: records}
  end

  def delete(store, transaction) do
    Directory.remove(store.root_directory, transaction)
  end

  def record(%__MODULE__{records: records}, mod) do
    Map.fetch!(records, mod)
  end

  def index(store, mod, name) do
    record(store, mod).indices_by_name[name]
  end
end
