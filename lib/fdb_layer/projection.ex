defmodule FDBLayer.Projection do
  defstruct [:fun, :arity]

  def new(fun) do
    {:arity, arity} = :erlang.fun_info(fun, :arity)
    %__MODULE__{fun: fun, arity: arity}
  end

  def key(projection, value) do
    [{key, _}] = __MODULE__.apply(projection, value)
    key
  end

  def apply(%__MODULE__{fun: fun, arity: 1}, value) do
    fun.(value)
    |> normalize
  end

  def apply(%__MODULE__{fun: fun, arity: 2}, old, new) do
    fun.(old, new)
    |> normalize
  end

  defp normalize(key_val) when is_tuple(key_val) do
    [key_val]
  end

  defp normalize(key_values) when is_list(key_values) do
    key_values
  end
end
