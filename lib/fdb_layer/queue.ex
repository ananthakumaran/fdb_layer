defmodule FDBLayer.Queue do
  alias FDB.{Coder, Transaction, Option, KeySelectorRange}

  defstruct [:item_coder, :metadata_coder]

  def new(%{subspace: subspace} = opts) do
    coder = Map.get(opts, :coder, FDBLayer.Coder.MsgPack.new())

    metadata_coder =
      Transaction.Coder.new(
        Coder.Subspace.concat(
          subspace,
          Coder.Subspace.new({0, Coder.Integer.new()}, Coder.ByteString.new())
        ),
        Coder.LittleEndianInteger.new()
      )

    item_coder =
      Transaction.Coder.new(
        Coder.Subspace.concat(
          subspace,
          Coder.Subspace.new({1, Coder.Integer.new()}, Coder.Versionstamp.new())
        ),
        coder
      )

    %__MODULE__{metadata_coder: metadata_coder, item_coder: item_coder}
  end

  def enqueue(queue, transaction, item, order \\ 0) do
    :ok =
      Transaction.set_versionstamped_key(transaction, FDB.Versionstamp.incomplete(order), item, %{
        coder: queue.item_coder
      })

    :ok =
      Transaction.atomic_op(transaction, "size", Option.mutation_type_add(), 1, %{
        coder: queue.metadata_coder
      })
  end

  def size(queue, transaction) do
    Transaction.get(transaction, "size", %{
      coder: queue.metadata_coder
    }) || 0
  end

  def dequeue(queue, transaction) do
    result =
      Transaction.get_range(transaction, KeySelectorRange.starts_with(nil), %{
        coder: queue.item_coder,
        limit: 1
      })
      |> Enum.to_list()

    case result do
      [] ->
        nil

      [{key, value}] ->
        :ok =
          Transaction.atomic_op(transaction, "size", Option.mutation_type_add(), -1, %{
            coder: queue.metadata_coder
          })

        Transaction.clear(transaction, key, %{
          coder: queue.item_coder
        })

        value
    end
  end
end
