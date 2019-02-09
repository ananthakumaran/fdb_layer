defmodule Sample.Comment do
  use Protobuf, from: Path.join(__DIR__, "blog.proto"), only: [:Comment], inject: true
end
