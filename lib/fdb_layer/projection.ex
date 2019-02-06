defmodule FDBLayer.Projection do
  defstruct [:fun]

  def new(fun) do
    %__MODULE__{fun: fun}
  end

  def key(projection, value) do
    [{key, _}] = __MODULE__.apply(projection, value)
    key
  end

  def apply(%__MODULE__{fun: fun}, value) do
    fun.(value)
    |> normalize
  end

  defp normalize(key_val) when is_tuple(key_val) do
    [key_val]
  end

  defp normalize(key_values) when is_list(key_values) do
    key_values
  end
end
