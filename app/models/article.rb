class Article
  include ActiveModel::Model
  attr_accessor :id, :slug, :title, :description, :body, :tag_list, :created_at, :updated_at, :author_id, :type

  validates :title, presence: true
  validates :body, presence: true
  validates :author_id, presence: true

  def save
    validate!
    bucket = Rails.application.config.couchbase_bucket
    self.id ||= SecureRandom.uuid
    self.slug ||= generate_slug(title)
    self.created_at ||= Time.now
    self.updated_at ||= Time.now
    bucket.default_collection.upsert(id, to_hash)
  end

  def update(attributes)
    attributes.each do |key, value|
      send("#{key}=", value)
    end
    save
  end

  def destroy
    bucket = Rails.application.config.couchbase_bucket
    bucket.default_collection.remove(id)
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
      'author_id' => author_id,
      'type' => 'article'
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
    query = "SELECT META().id, * FROM `realworld-rails` WHERE `type` = 'comment' AND `article_id` = $1"
    result = cluster.query(query, [id])
    result.rows.map { |row| Comment.new(row) }
  end

  def add_comment(comment)
    comment = Comment.new(comment) unless comment.is_a?(Comment)
    comment.author_id = author_id
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

  def generate_slug(title)
    return nil if title.nil?
    @slug ||= title.parameterize(separator: '-')
  end

  def validate!
    raise ActiveModel::ValidationError, self if invalid?
  end
end
