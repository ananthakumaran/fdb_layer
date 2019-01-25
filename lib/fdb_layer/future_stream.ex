defmodule FDBLayer.FutureStream do
  alias FDB.Future

  def map(stream, callback, options \\ %{}) do
    concurrency = Map.get(options, :concurrency, 10)
    eos = make_ref()
    Stream.concat(stream, [eos])
    |> Stream.transform(:queue.new(), fn i, pending ->
      length = :queue.len(pending)
      cond do
        i == eos ->
          rest = :queue.to_list(pending)
          |> Enum.map(&Future.await/1)
          {rest, nil}
        length < concurrency ->
          pending = :queue.snoc(pending, callback.(i))
          {[], pending}
        length == concurrency ->
          {{:value, future}, pending} = :queue.out(pending)
          value = Future.await(future)
          pending = :queue.snoc(pending, callback.(i))
          {[value], pending}
      end
    end)
  end
end
