class User
  include ActiveModel::Model
  attr_accessor :id, :username, :email, :password_digest, :bio, :image, :type, :password, :following, :favorites

  validates :username, presence: true
  validates :email, presence: true
  validates :password_digest, presence: true
  validates :password, presence: true, on: :create


  def save
    self.password_digest = BCrypt::Password.create(password) if password.present?
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
      'image' => image,
      'following' => following || [],
      'favorites' => favorites || []
    }
  end

  def self.find(id)
    cluster = Rails.application.config.couchbase_cluster
    options = Couchbase::Options::Query.new
    options.positional_parameters([id])
    result = cluster.query("SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE META().id = ? LIMIT 1", options)
    if result.rows.any?
      row = result.rows.first
      User.new(row["_default"].merge('id' => row['id']))
    end
  end


  def self.find_by_email(email)
    cluster = Rails.application.config.couchbase_cluster
    options = Couchbase::Options::Query.new
    options.positional_parameters([email])
    result = cluster.query("SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `email` = ? LIMIT 1", options)
    if result.rows.any?
      row = result.rows.first
      User.new(row["_default"].merge('id' => row['id']))
    end
  end


  def self.find_by_username(username)
    cluster = Rails.application.config.couchbase_cluster
    options = Couchbase::Options::Query.new
    options.positional_parameters([username])
    result = cluster.query("SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `username` = ? LIMIT 1", options)
    puts result
    if result.rows.any?
      row = result.rows.first
      User.new(row["_default"].merge('id' => row['id']))
    end
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
    following = result.content(0) rescue []
    following.include?(user.id)
  end

  def favorited_articles
    bucket = Rails.application.config.couchbase_bucket
    collection = bucket.default_collection
    result = collection.lookup_in(id, [
      Couchbase::LookupInSpec.get('favorites')
    ])
    favorite_ids = result.content(0) rescue []
    find_by_ids(favorite_ids)
  end

  def favorite(article)
    bucket = Rails.application.config.couchbase_bucket
    collection = bucket.default_collection

    exists_result = collection.lookup_in(id, [Couchbase::LookupInSpec.exists('favorites')])
    unless exists_result.exists?(0)
      collection.mutate_in(id, [
        Couchbase::MutateInSpec.insert('favorites', [])
      ])
    end

    collection.mutate_in(id, [
      Couchbase::MutateInSpec.array_add_unique('favorites', article.id)
    ])
  end

  def unfavorite(article)
    bucket = Rails.application.config.couchbase_bucket
    collection = bucket.default_collection

    exists_result = collection.lookup_in(id, [Couchbase::LookupInSpec.exists('favorites')])
    unless exists_result.exists?(0)
      return
    end

    collection.mutate_in(id, [
      Couchbase::MutateInSpec.array_remove('favorites', article.id)
    ])
  end

  def favorited?(article)
    bucket = Rails.application.config.couchbase_bucket
    collection = bucket.default_collection

    exists_result = collection.lookup_in(id, [Couchbase::LookupInSpec.exists('favorites')])
    unless exists_result.exists?(0)
      return false
    end

    result = collection.lookup_in(id, [
      Couchbase::LookupInSpec.get('favorites')
    ])
    favorites = result.content(0)

    favorites.include?(article.id)
  end

  def articles
    cluster = Rails.application.config.couchbase_cluster
    options = Couchbase::Options::Query.new
    options.positional_parameters([id])
    query = "SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `type` = 'article' AND `author_id` = ?"
    result = cluster.query(query, options)
    result.rows.map { |row| Article.new(row["_default"]) }
  end

  def find_by_ids(ids)
    return [] if ids.empty?

    cluster = Rails.application.config.couchbase_cluster
    options = Couchbase::Options::Query.new
    options.positional_parameters([ids])
    result = cluster.query("SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE META().id IN $1", options)
    result.rows.map { |row| Article.new(row['_default'].merge('id' => row['id'])) }
  end

  def find_article_by_slug(slug)
    cluster = Rails.application.config.couchbase_cluster
    options = Couchbase::Options::Query.new
    options.positional_parameters([slug, id])
    result = cluster.query("SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `slug` = ? AND `author_id` = ? LIMIT 1", options)
    if result.rows.any?
      row = result.rows.first
      Article.new(row["_default"].merge('id' => row['id']))
    end
  end

  def feed
    cluster = Rails.application.config.couchbase_cluster
    query = "SELECT META().id, * FROM `RealWorldRailsBucket-rails` WHERE `author_id` IN $1 ORDER BY `createdAt` DESC"
    result = cluster.query(query, [following])
    result.rows.map { |row| Article.new(row) }
  end

  def validate!
    raise ActiveModel::ValidationError, self if invalid?
  end
end
