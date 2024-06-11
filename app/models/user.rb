# frozen_string_literal: true

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
    result = cluster.query(
      'SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE META().id = ? LIMIT 1', options
    )
    return unless result.rows.any?

    row = result.rows.first
    User.new(row['_default'].merge('id' => row['id']))
  end

  def self.find_by_email(email)
    cluster = Rails.application.config.couchbase_cluster
    options = Couchbase::Options::Query.new
    options.positional_parameters([email])
    result = cluster.query(
      'SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `email` = ? LIMIT 1', options
    )
    return unless result.rows.any?

    row = result.rows.first
    User.new(row['_default'].merge('id' => row['id']))
  end

  def self.find_by_username(username)
    cluster = Rails.application.config.couchbase_cluster
    options = Couchbase::Options::Query.new
    options.positional_parameters([username])
    result = cluster.query(
      'SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `username` = ? LIMIT 1', options
    )

    return unless result.rows.any?

    row = result.rows.first
    User.new(row['_default'].merge('id' => row['id']))
  end

  def follow(user)
    bucket = Rails.application.config.couchbase_bucket
    collection = bucket.default_collection

    exists_result = collection.lookup_in(id, [Couchbase::LookupInSpec.exists('following')])
    unless exists_result.exists?(0)
      collection.mutate_in(id, [
                             Couchbase::MutateInSpec.insert('following', [])
                           ])
    end

    collection.mutate_in(id, [
                           Couchbase::MutateInSpec.array_add_unique('following', user.id)
                         ])
  end

  def unfollow(user)
    bucket = Rails.application.config.couchbase_bucket
    collection = bucket.default_collection

    exists_result = collection.lookup_in(id, [Couchbase::LookupInSpec.exists('following')])
    return unless exists_result.exists?(0)

    result = collection.lookup_in(id, [Couchbase::LookupInSpec.get('following')])
    following = result.content(0)

    return unless following.include?(user.id)

    following.delete(user.id)

    collection.mutate_in(id, [
                           Couchbase::MutateInSpec.replace('following', following)
                         ])
  end

  def following?(user)
    bucket = Rails.application.config.couchbase_bucket
    collection = bucket.default_collection

    begin
      exists_result = collection.lookup_in(id, [Couchbase::LookupInSpec.exists('following')])
    rescue Couchbase::Error::DocumentNotFound
      return false
    end

    return false unless exists_result.exists?(0)

    result = collection.lookup_in(id, [
                                    Couchbase::LookupInSpec.get('following')
                                  ])

    following = begin
      result.content(0)
    rescue StandardError
      []
    end
    following.include?(user.id)
  end

  def favorited_articles
    bucket = Rails.application.config.couchbase_bucket
    collection = bucket.default_collection
    result = collection.lookup_in(id, [
                                    Couchbase::LookupInSpec.get('favorites')
                                  ])
    favorite_ids = begin
      result.content(0)
    rescue StandardError
      []
    end
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
    collection.mutate_in(article.id, [
                           Couchbase::MutateInSpec.increment('favorites_count', 1)
                         ])
  end

  def unfavorite(article)
    bucket = Rails.application.config.couchbase_bucket
    collection = bucket.default_collection

    exists_result = collection.lookup_in(id, [Couchbase::LookupInSpec.exists('favorites')])
    return unless exists_result.exists?(0)

    result = collection.lookup_in(id, [Couchbase::LookupInSpec.get('favorites')])
    favorites = result.content(0)

    return unless favorites.include?(article.id)

    favorites.delete(article.id)

    collection.mutate_in(id, [
                           Couchbase::MutateInSpec.replace('favorites', favorites)
                         ])
    collection.mutate_in(article.id, [
                           Couchbase::MutateInSpec.decrement('favorites_count', 1)
                         ])
  end

  def favorited?(article)
    bucket = Rails.application.config.couchbase_bucket
    collection = bucket.default_collection

    exists_result = collection.lookup_in(id, [Couchbase::LookupInSpec.exists('favorites')])
    return false unless exists_result.exists?(0)

    result = collection.lookup_in(id, [
                                    Couchbase::LookupInSpec.get('favorites')
                                  ])

    favorites = begin
      result.content(0)
    rescue StandardError
      []
    end
    favorites.include?(article.id)
  end

  def favorited_by?(username)
    user = User.find_by_username(username)
    user.favorites.include?(self.id)
  end

  def articles
    cluster = Rails.application.config.couchbase_cluster
    options = Couchbase::Options::Query.new
    options.positional_parameters([id])
    query = "SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `type` = 'article' AND `author_id` = ?"
    result = cluster.query(query, options)
    result.rows.map { |row| Article.new(row['_default']) }
  end

  def find_by_ids(ids)
    return [] if ids.empty?

    cluster = Rails.application.config.couchbase_cluster
    options = Couchbase::Options::Query.new
    options.positional_parameters([ids])
    result = cluster.query('SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE META().id IN $1',
                           options)
    result.rows.map { |row| Article.new(row['_default'].merge('id' => row['id'])) }
  end

  def find_article_by_slug(slug)
    cluster = Rails.application.config.couchbase_cluster
    options = Couchbase::Options::Query.new
    options.positional_parameters([slug, id])
    result = cluster.query(
      'SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `slug` = ? AND `author_id` = ? LIMIT 1', options
    )
    return unless result.rows.any?

    row = result.rows.first
    Article.new(row['_default'].merge('id' => row['id']))
  end

  def feed
    feed = []

    cluster = Rails.application.config.couchbase_cluster
    options = Couchbase::Options::Query.new
    options.positional_parameters([following])
    result = cluster.query(
      'SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `author_id` IN ?', options
    )

    result.rows.each do |row|
      parsed_row = begin
        JSON.parse(row)
      rescue StandardError
        row
      end
      article_data = parsed_row['_default'].merge('id' => parsed_row['id'])
      feed << Article.new(article_data)
    end
    feed
  end

  def validate!
    raise ActiveModel::ValidationError, self if invalid?
  end
end
