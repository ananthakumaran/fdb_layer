defprotocol FDBLayer.Index do
  def create(index, transaction, new_record)

  def update(index, transaction, _old_record, new_record)

  def delete(index, transaction, current_record)
end
