defmodule FDBLayer.Index do
  defstruct [:name, :key_expression, :type]

  def new(name, type, key_expression) do
    %__MODULE__{name: name, key_expression: key_expression, type: type}
  end

  def create(index, new_record) do
  end

  def update(index, old_record, new_record) do
  end

  def delete(index, current_record) do
  end
end
