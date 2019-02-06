defmodule FDBLayer.Changeset do
  @moduledoc false

  defstruct created: [], updated: [], deleted: [], unchanged: []

  def construct(old, new) do
    new = Enum.into(new, %{})
    changeset = %__MODULE__{}

    {changeset, new} =
      Enum.reduce(old, {changeset, new}, fn {key, value}, {changeset, new} ->
        case Map.pop(new, key) do
          {nil, new} ->
            {%{changeset | deleted: [{key, value} | changeset.deleted]}, new}

          {new_value, new} ->
            if new_value == value do
              {%{changeset | unchanged: [{key, value} | changeset.unchanged]}, new}
            else
              {%{changeset | updated: [{key, value, new_value} | changeset.updated]}, new}
            end
        end
      end)

    %{changeset | created: Map.to_list(new)}
  end
end
