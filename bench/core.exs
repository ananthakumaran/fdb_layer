alias FDB.Transaction

defmodule Conflicts do
  use Agent
  @initial %{}

  def start_link() do
    Agent.start_link(fn -> @initial end, name: __MODULE__)
  end

  def get() do
    Agent.get_and_update(__MODULE__, &{&1, @initial})
  end

  def init(name) do
    Agent.update(__MODULE__, fn s -> Map.put(s, name, 0) end)
  end

  def update(name, count) do
    Agent.update(__MODULE__, fn s -> %{s | name => s[name] + count} end)
  end

  def measure(name, db, callback) do
    do_measure(name, Transaction.create(db), 0, callback)
  end

  defp do_measure(name, transaction, conflicts, callback) do
    result = callback.(transaction)
    :ok = Transaction.commit(transaction)
    result
  rescue
    e in FDB.Error ->
      update(name, 1)
      :ok = Transaction.on_error(transaction, e.code)
      do_measure(name, transaction, conflicts + 1, callback)
  end
end

Conflicts.start_link()

File.write!("result.ndjson", "", [:write])

defmodule Benchee.Formatters.FDB do
  use Benchee.Formatter

  def format(suite) do
    concurrency = suite.configuration.parallel
    conflicts = Conflicts.get()

    Enum.map(suite.scenarios, fn s ->
      stats = s.run_time_statistics

      ops_scale =
        cond do
          s.job_name =~ "10 op" -> 10 * concurrency
          true -> concurrency
        end

      %{
        name: s.job_name,
        concurrency: concurrency,
        ops: ops_scale * stats.ips,
        average: stats.average / 1000,
        max: stats.maximum / 1000,
        min: stats.minimum / 1000,
        deviation: stats.std_dev_ratio * 100,
        conflicts: Map.get(conflicts, String.to_atom(s.job_name))
      }
    end)
  end

  def write(scenarios) do
    pattern = "~*s~*s~*s~*s~*s~*s~*s~*s\n"
    widths = [15, 15, 15, 10, 13, 10, 10, 12]

    format(pattern, widths, [
      "name",
      "concurrency",
      "conflicts",
      "ops/s",
      "average ms",
      "max ms",
      "min ms",
      "deviation"
    ])

    Enum.each(scenarios, fn s ->
      File.write!("result.ndjson", [Jason.encode!(s), "\n"], [:append])

      format(pattern, widths, [
        s.name,
        to_string(s.concurrency),
        to_string(s.conflicts),
        to_string(trunc(s.ops)),
        Float.to_string(Float.round(s.average, 3)),
        Float.to_string(Float.round(s.max, 3)),
        Float.to_string(Float.round(s.min, 3)),
        to_charlist(" ±" <> Float.to_string(Float.round(s.deviation, 2)) <> "%")
      ])
    end)
  end

  defp format(pattern, widths, values) do
    args =
      Enum.with_index(values)
      |> Enum.map(fn {value, i} ->
        [Enum.at(widths, i), value]
      end)
      |> Enum.concat()

    :io.fwrite(pattern, args)
  end
end
