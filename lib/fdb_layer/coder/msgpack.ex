defmodule FDBLayer.Coder.MsgPack do
  use FDB.Coder.Behaviour

  @spec new() :: FDB.Coder.t()
  def new do
    %FDB.Coder{module: __MODULE__}
  end

  @impl true
  def encode(term, _) do
    Msgpax.pack!(term, iodata: false)
  end

  @impl true
  def decode(iodata, _) do
    Msgpax.unpack_slice!(iodata)
  end
end
