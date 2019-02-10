defmodule FDBLayer.Coder.Term do
  use FDB.Coder.Behaviour

  @spec new() :: FDB.Coder.t()
  def new do
    %FDB.Coder{module: __MODULE__}
  end

  @impl true
  def encode(term, _) do
    :erlang.term_to_binary(term)
  end

  @impl true
  def decode(iodata, _) do
    {:erlang.binary_to_term(iodata), ""}
  end
end
