defmodule FDBLayer.KeyExpression do
  defstruct [:path, :coder]

  def field(opts) do
    %__MODULE__{path: [Access.key(opts.field)], coder: opts.coder}
  end

  def fetch(%__MODULE__{path: path}, value) do
    get_in(value, path)
  end
end
