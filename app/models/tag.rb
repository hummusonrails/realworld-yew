class Tag
  include ActiveModel::Model
  attr_accessor :name, :type

  def save
    bucket = Rails.application.config.couchbase_bucket
    self.id ||= SecureRandom.uuid
    bucket.default_collection.upsert(id, to_hash)
  end

  def to_hash
    {
      'name' => name,
      'type' => 'tag'
    }
  end
end
