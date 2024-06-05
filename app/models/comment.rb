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

  def destroy
    bucket = Rails.application.config.couchbase_bucket
    bucket.default_collection.remove(id)
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

  def self.find(id)
    cluster = Rails.application.config.couchbase_cluster
    query = "SELECT META().id, * FROM `realworld-rails` WHERE `type` = 'comment' AND `id` = $1 LIMIT 1"
    result = cluster.query(query, [id])
    Comment.new(result.rows.first) if result.rows.any?
  end

  def validate!
    raise ActiveModel::ValidationError, self if invalid?
  end
end
