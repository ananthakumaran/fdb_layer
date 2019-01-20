defmodule FDBLayer do
  defmodule DuplicateRecordError do
    defexception [:message]

    @type t :: %__MODULE__{message: binary}
  end

  defmodule RecordNotFoundError do
    defexception [:message]

    @type t :: %__MODULE__{message: binary}
  end
end
