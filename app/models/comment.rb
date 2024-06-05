class Comment
  include ActiveModel::Model
  attr_accessor :id, :body, :author_id, :created_at, :updated_at, :article_id, :type

  validates :body, presence: true
  validates :author_id, presence: true

  def save
    validate!
    bucket = Rails.application.config.couchbase_bucket
    self.id ||= SecureRandom.uuid
    self.created_at ||= Time.now
    self.updated_at ||= Time.now
    bucket.default_collection.upsert(id, to_hash)
  end

  def to_hash
    {
      'type' => 'comment',
      'body' => body,
      'author_id' => author_id,
      'created_at' => created_at,
      'updated_at' => updated_at,
      'article_id' => article_id
    }
  end

  def validate!
    raise ActiveModel::ValidationError, self if invalid?
  end
end
