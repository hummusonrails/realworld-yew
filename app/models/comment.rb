class Comment
  include ActiveModel::Model
  attr_accessor :id, :body, :author, :created_at, :updated_at, :article_id

  def save
    bucket = Rails.application.config.couchbase_bucket
    self.id ||= SecureRandom.uuid
    self.created_at ||= Time.now
    self.updated_at ||= Time.now
    bucket.default_collection.upsert(id, to_hash)
  end

  def to_hash
    {
      'body' => body,
      'author' => author.to_hash,
      'created_at' => created_at,
      'updated_at' => updated_at,
      'article_id' => article_id
    }
  end
end