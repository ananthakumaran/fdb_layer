defmodule Sample do
  @external_resource "test/support/blog.proto"

  use Protox,
    files: [
      "test/support/blog.proto"
    ]
end
