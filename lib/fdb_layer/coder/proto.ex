defmodule FDBLayer.Coder.Proto do
  use FDB.Coder.Behaviour

  @spec new(atom) :: FDB.Coder.t()
  def new(message) do
    %FDB.Coder{module: __MODULE__, opts: message}
  end

  @impl true
  def encode(term, message) do
    message.encode(term)
  end

  @impl true
  def decode(iodata, message) do
    {message.decode(iodata), ""}
  end
end
