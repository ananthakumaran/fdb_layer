defmodule FDBLayer.Queue do
  alias FDB.{Coder, Transaction, Option, KeySelectorRange}

  defstruct [:item_coder, :metadata_coder, :partitions]

  def new(%{subspace: subspace} = opts) do
    coder = Map.get(opts, :coder, FDBLayer.Coder.MsgPack.new())
    partitions = 0..(Map.get(opts, :partition, 1) - 1)

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
          Coder.Subspace.new(
            {1, Coder.Integer.new()},
            Coder.Tuple.new({Coder.Integer.new(), Coder.Versionstamp.new()})
          )
        ),
        coder
      )

    %__MODULE__{metadata_coder: metadata_coder, item_coder: item_coder, partitions: partitions}
  end

  def enqueue(queue, transaction, item, opts \\ %{}) do
    order = Map.get(opts, :order, 0)
    partition = Map.get(opts, :partition) || Enum.random(queue.partitions)

    :ok =
      Transaction.set_versionstamped_key(
        transaction,
        {partition, FDB.Versionstamp.incomplete(order)},
        item,
        %{
          coder: queue.item_coder
        }
      )

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
      if size(queue, transaction) == 0 do
        []
      else
        Transaction.get_range(
          transaction,
          KeySelectorRange.starts_with({Enum.random(queue.partitions)}),
          %{
            coder: queue.item_coder,
            limit: 1,
            snapshot: true
          }
        )
        |> Enum.to_list()
      end

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
