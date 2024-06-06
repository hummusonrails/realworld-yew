class Article
  include ActiveModel::Model
  attr_accessor :id, :slug, :title, :description, :body, :tag_list, :created_at, :updated_at, :author_id, :type, :favorites

  validates :title, presence: true
  validates :body, presence: true
  validates :author_id, presence: true

  def initialize(attributes = {})
    super
    self.created_at = Time.parse(created_at) if created_at.is_a?(String)
    self.updated_at = Time.parse(updated_at) if updated_at.is_a?(String)
  end

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
      'type' => 'article',
      'favorites' => favorites || []
    }
  end

  def self.find_by_slug(slug)
    cluster = Rails.application.config.couchbase_cluster
    options = Couchbase::Options::Query.new
    options.positional_parameters([slug])
    result = cluster.query("SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `type` = 'article' AND `slug` = ? LIMIT 1", options)
    if result.rows.any?
      row = result.rows.first
      Article.new(row['_default'].merge('id' => row['id']))
    end
  end

  def self.all
    cluster = Rails.application.config.couchbase_cluster
    query = "SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `type` = 'article'"
    result = cluster.query(query)
    articles = []
    if result.rows.any?
      articles = result.rows.map do |row|
        article_data = row['_default']
        next if article_data.nil?

        article_data['id'] = row['id']
        Article.new(article_data)
      end
    end
    articles.compact
  end


  def comments
    cluster = Rails.application.config.couchbase_cluster
    options = Couchbase::Options::Query.new
    options.positional_parameters([id])
    result = cluster.query("SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `type` = 'comment' AND `article_id` = ?", options)
    comments = []
    if result.rows.any?
      comments = result.rows.map do |row|
        comment_data = row['_default']
        next if comment_data.nil?

        comment_data['id'] = row['id']
        Comment.new(comment_data)
      end
    end
    comments.compact
  end

  def add_comment(comment)
    comment = Comment.new(comment) unless comment.is_a?(Comment)
    comment.author_id = author_id
    comment.article_id = id
    comment.save
  end

  def tags
    return [] if tag_list.blank?
    tag_list.is_a?(String) ? tag_list.split(',').map(&:strip) : tag_list
  end

  def add_tag(tag)
    self.tag_list = '' if tag_list.nil?
    tag_list << tag unless tag_list.include?(tag)
    save
  end

  def remove_tag(tag)
    tag_list.delete(tag)
    save
  end

  def favorites_count
    if favorites
      favorites.length
    else
      0
    end
  end

  def generate_slug(title)
    return nil if title.nil?
    @slug ||= title.parameterize(separator: '-')
  end

  def author
    User.find(author_id)
  end

  def validate!
    raise ActiveModel::ValidationError, self if invalid?
  end
end
