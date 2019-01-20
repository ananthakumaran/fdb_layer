alias FDB.Database
alias FDB.Transaction
alias FDB.KeyRange
alias FDB.Coder
alias FDBLayer.Queue

Code.require_file("core.exs", __DIR__)

:ok = FDB.start()

db =
  FDB.Cluster.create()
  |> Database.create()

runs = 1..5
queue = Queue.new(%{subspace: Coder.Subspace.new("q"), partition: 64})

Database.transact(db, fn t ->
  :ok =
    Transaction.clear_range(
      t,
      KeyRange.range("", <<0xFF>>)
    )
end)

Enum.each(runs, fn concurrency ->
  concurrency = concurrency * 100
  Conflicts.init(:queue)

  Benchee.run(
    %{
      queue: fn ->
        Conflicts.measure(:queue, db, fn t ->
          if Enum.random(1..10) > 5 do
            :ok = Queue.enqueue(queue, t, 1)
          else
            Queue.dequeue(queue, t)
          end
        end)
      end
    },
    parallel: concurrency,
    formatters: [Benchee.Formatters.FDB],
    before_scenario: fn input ->
      input
    end
  )
end)
