class Tag
  include ActiveModel::Model
  attr_accessor :name

  def save
    bucket = Rails.application.config.couchbase_bucket
    self.id ||= SecureRandom.uuid
    bucket.default_collection.upsert(id, to_hash)
  end

  def to_hash
    { 'name' => name }
  end
end
