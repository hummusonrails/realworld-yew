class Article
  include ActiveModel::Model
  attr_accessor :id, :slug, :title, :description, :body, :tag_list, :created_at, :updated_at, :author

  def save
    bucket = Rails.application.config.couchbase_bucket
    self.id ||= SecureRandom.uuid
    self.slug ||= generate_slug(title)
    self.created_at ||= Time.now
    self.updated_at ||= Time.now
    bucket.default_collection.upsert(id, to_hash)
  end

  def to_hash
    {
      'slug' => slug,
      'title' => title,
      'description' => description,
      'body' => body,
      'tag_list' => tag_list,
      'created_at' => created_at,
      'updated_at' => updated_at,
      'author' => author.to_hash
    }
  end

  def self.find_by_slug(slug)
    cluster = Rails.application.config.couchbase_cluster
    query = "SELECT META().id, * FROM `realworld-rails` WHERE `slug` = $1 LIMIT 1"
    result = cluster.query(query, [slug])
    Article.new(result.rows.first) if result.rows.any?
  end

  def self.all
    cluster = Rails.application.config.couchbase_cluster
    query = "SELECT META().id, * FROM `realworld-rails` WHERE `type` = 'article'"
    result = cluster.query(query)
    result.rows.map { |row| Article.new(row) }
  end

  def comments
    cluster = Rails.application.config.couchbase_cluster
    query = "SELECT META().id, * FROM `realworld-rails` WHERE `article_id` = $1"
    result = cluster.query(query, [id])
    result.rows.map { |row| Comment.new(row) }
  end

  def add_comment(comment)
    comment.article_id = id
    comment.save
  end

  def tags
    tag_list.split(',').map(&:strip)
  end

  def add_tag(tag)
    tag_list << tag unless tag_list.include?(tag)
    save
  end

  def remove_tag(tag)
    tag_list.delete(tag)
    save
  end
end
