defmodule FDBLayer.Index do
  alias FDBLayer.Index.Protocol

  defdelegate init(index, transaction, root_directory), to: Protocol

  defdelegate create(index, transaction, new_record), to: Protocol

  defdelegate update(index, transaction, old_record, new_record), to: Protocol

  defdelegate delete(index, transaction, current_record), to: Protocol

  defdelegate scan(index, database_or_transaction, key_selector_range),
    to: Protocol
end
