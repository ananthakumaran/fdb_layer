defmodule Sample.Post do
  use FDBLayer.Record
  alias FDBLayer.{Projection, Index}

  alias FDB.Coder.{
    ByteString,
    Tuple,
    LittleEndianInteger,
    SignedLittleEndianInteger,
    Versionstamp
  }

  alias FDBLayer.Coder.{Proto, Term}
  alias FDB.Transaction
  use Protobuf, from: Path.join(__DIR__, "blog.proto"), only: [:Post], inject: true

  @impl true
  def primary_index do
    Index.Primary.new(%{
      path: ["record", "posts"],
      name: "posts",
      coder: Transaction.Coder.new(ByteString.new(), Proto.new(__MODULE__)),
      projection: Projection.new(fn p -> {p.id, p} end)
    })
  end

  @impl true
  def indices do
    [
      Index.Value.new(%{
        name: "users_posts",
        path: ["index", "users", "post_id"],
        coder:
          Transaction.Coder.new(Tuple.new({ByteString.new(), ByteString.new()}), ByteString.new()),
        projection: Projection.new(fn p -> {{p.user_id, p.id}, ""} end)
      }),
      Index.Aggregate.new(%{
        name: "posts_count",
        path: ["index", "posts", "count"],
        coder: Transaction.Coder.new(ByteString.new(), LittleEndianInteger.new()),
        type: Index.Aggregate.Count,
        projection: Projection.new(fn _p -> {"", 1} end)
      }),
      Index.Aggregate.new(%{
        name: "users_posts_count",
        path: ["index", "users", "posts_count"],
        coder: Transaction.Coder.new(ByteString.new(), LittleEndianInteger.new()),
        type: Index.Aggregate.Count,
        projection: Projection.new(fn p -> {p.user_id, 1} end)
      }),
      Index.Aggregate.new(%{
        name: "users_claps_sum",
        path: ["index", "users", "claps_sum"],
        type: Index.Aggregate.Sum,
        coder: Transaction.Coder.new(ByteString.new(), SignedLittleEndianInteger.new()),
        projection: Projection.new(fn p -> {p.user_id, p.claps} end)
      }),
      Index.Value.new(%{
        name: "users_comments",
        path: ["index", "users", "comments"],
        coder:
          Transaction.Coder.new(
            Tuple.new({ByteString.new(), ByteString.new()}),
            Proto.new(Sample.Comment)
          ),
        projection:
          Projection.new(fn p -> Enum.map(p.comments, fn c -> {{c.user_id, c.id}, c} end) end)
      }),
      Index.Version.new(%{
        name: "posts_changes",
        path: ["index", "posts", "changes"],
        coder:
          Transaction.Coder.new(
            Tuple.new({ByteString.new(), Versionstamp.new()}),
            Term.new()
          ),
        projection:
          Projection.new(fn old, new ->
            prev =
              if old do
                old.content
              else
                ""
              end

            next =
              if new do
                new.content
              else
                ""
              end

            {{(old || new).id, FDB.Versionstamp.incomplete()},
             String.myers_difference(prev, next)}
          end)
      })
    ]
  end
end
