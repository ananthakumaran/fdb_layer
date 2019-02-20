defmodule FDBLayer.Coder.Avro do
  use FDB.Coder.Behaviour

  @spec new(term) :: FDB.Coder.t()
  def new(schema) do
    schema_json = Jason.encode!(schema)

    %FDB.Coder{
      module: __MODULE__,
      opts: %{
        encoder: :avro.make_simple_encoder(schema_json, []),
        decoder: :avro.make_simple_decoder(schema_json, record_type: :map, map_type: :map)
      }
    }
  end

  @impl true
  def encode(term, %{encoder: encoder}) do
    encoder.(term)
    |> IO.iodata_to_binary()
  end

  @impl true
  def decode(iodata, %{decoder: decoder}) do
    {decoder.(iodata), ""}
  end
end
