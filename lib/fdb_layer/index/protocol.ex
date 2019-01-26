defprotocol FDBLayer.Index.Protocol do
  def init(index, transaction, root_directory)

  def create(index, transaction, new_record)

  def update(index, transaction, _old_record, new_record)

  def delete(index, transaction, current_record)

  def scan(index, database_or_transaction, key_selector_range)
end
