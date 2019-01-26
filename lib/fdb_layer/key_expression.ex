defmodule FDBLayer.KeyExpression do
  defstruct [:path, :coder]

  def empty() do
    %__MODULE__{path: [], coder: FDB.Coder.ByteString.new()}
  end

  def field(opts) do
    %__MODULE__{path: [Access.key(opts.field)], coder: opts.coder}
  end

  def concat(a, b) do
    concat = fn :get, data, next ->
      left = get_in(data, a.path)
      right = get_in(data, b.path)
      next.(append(left, right))
    end

    %__MODULE__{path: [concat], coder: FDB.Coder.Tuple.new({a.coder, b.coder})}
  end

  def fetch(%__MODULE__{path: []}, _value) do
    ""
  end

  def fetch(%__MODULE__{path: path}, value) do
    get_in(value, path)
  end

  defp append(a, b) when is_tuple(a) and is_tuple(b) do
    (Tuple.to_list(a) ++ Tuple.to_list(b))
    |> List.to_tuple()
  end

  defp append(a, b) when is_tuple(a) do
    Tuple.append(a, b)
  end

  defp append(a, b) when is_tuple(b) do
    ([a] ++ Tuple.to_list(b))
    |> List.to_tuple()
  end

  defp append(a, b) do
    {a, b}
  end
end
