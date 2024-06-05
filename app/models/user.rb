class User
  include ActiveModel::Model
  attr_accessor :id, :username, :email, :password_digest, :bio, :image, :type

  validates :username, presence: true
  validates :email, presence: true
  validates :password_digest, presence: true

  def save
    validate!
    bucket = Rails.application.config.couchbase_bucket
    self.id ||= SecureRandom.uuid
    bucket.default_collection.upsert(id, to_hash)
  end

  def update(attributes)
    attributes.each do |key, value|
      send("#{key}=", value)
    end
    save
  end

  def to_hash
    {
      'type' => 'user',
      'username' => username,
      'email' => email,
      'password_digest' => password_digest,
      'bio' => bio,
      'image' => image
    }
  end

  def self.find(id)
    bucket = Rails.application.config.couchbase_bucket
    result = bucket.default_collection.get(id)
    User.new(result.content.merge(id: id)) if result.success?
  end

  def self.find_by_email(email)
    cluster = Rails.application.config.couchbase_cluster
    query = "SELECT META().id, * FROM `realworld-rails` WHERE `email` = $1 LIMIT 1"
    result = cluster.query(query, [email])
    User.new(result.rows.first) if result.rows.any?
  end

  def self.find_by_username(username)
    cluster = Rails.application.config.couchbase_cluster
    query = "SELECT META().id, * FROM `realworld-rails` WHERE `username` = $1 LIMIT 1"
    result = cluster.query(query, [username])
    User.new(result.rows.first) if result.rows.any?
  end

  def follow(user)
    bucket = Rails.application.config.couchbase_bucket
    collection = bucket.default_collection
    collection.mutate_in(id, [
      Couchbase::MutateInSpec.array_add_unique('following', user.id)
    ])
  end

  def unfollow(user)
    bucket = Rails.application.config.couchbase_bucket
    collection = bucket.default_collection
    collection.mutate_in(id, [
      Couchbase::MutateInSpec.array_remove('following', user.id)
    ])
  end

  def following?(user)
    bucket = Rails.application.config.couchbase_bucket
    collection = bucket.default_collection
    result = collection.lookup_in(id, [
      Couchbase::LookupInSpec.get('following')
    ])
    result.content(0).include?(user.id)
  end

  def favorite(article)
    bucket = Rails.application.config.couchbase_bucket
    collection = bucket.default_collection
    collection.mutate_in(id, [
      Couchbase::MutateInSpec.array_add_unique('favorites', article.id)
    ])
  end

  def unfavorite(article)
    bucket = Rails.application.config.couchbase_bucket
    collection = bucket.default_collection
    collection.mutate_in(id, [
      Couchbase::MutateInSpec.array_remove('favorites', article.id)
    ])
  end

  def favorited?(article)
    bucket = Rails.application.config.couchbase_bucket
    collection = bucket.default_collection
    result = collection.lookup_in(id, [
      Couchbase::LookupInSpec.get('favorites')
    ])
    result.content(0).include?(article.id)
  end

  def articles
    cluster = Rails.application.config.couchbase_cluster
    query = "SELECT META().id, * FROM `realworld-rails` WHERE `type` = 'article' AND `author_id` = $1"
    result = cluster.query(query, [id])
    result.rows.map { |row| Article.new(row) }
  end

  def find_article_by_slug(slug)
    cluster = Rails.application.config.couchbase_cluster
    options = Cluster::QueryOptions.new
    options.positional_parameters(["param1", "param2"])
    # query = "SELECT META().id, * FROM `realworld-rails` WHERE `slug` = $1 AND `author_id` = $2 LIMIT 1"
    result = cluster.query("SELECT META().id, * FROM `realworld-rails` WHERE `slug` = ? AND `author_id` = ? LIMIT 1", options)
    Article.new(result.rows.first) if result.rows.any?
  end


  def feed
    cluster = Rails.application.config.couchbase_cluster
    query = "SELECT META().id, * FROM `realworld-rails-rails` WHERE `author_id` IN $1 ORDER BY `createdAt` DESC"
    result = cluster.query(query, [following])
    result.rows.map { |row| Article.new(row) }
  end

  def validate!
    raise ActiveModel::ValidationError, self if invalid?
  end
end
