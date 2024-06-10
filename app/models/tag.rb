# frozen_string_literal: true

class Tag
  include ActiveModel::Model
  attr_accessor :id, :name, :type

  validates :name, presence: true

  def save
    validate!
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

  def self.all
    cluster = Rails.application.config.couchbase_cluster
    query = "SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `type` = 'tag'"
    result = cluster.query(query)
    if result.rows.any?
      result.rows.map do |row|
        tag_data = row
        next if tag_data.nil?

        tag_data['id'] = row['id']
        Tag.new(tag_data['_default'])
      end.compact
    else
      []
    end
  end

  def self.count
    cluster = Rails.application.config.couchbase_cluster
    query = "SELECT COUNT(*) AS count FROM RealWorldRailsBucket.`_default`.`_default` WHERE `type` = 'tag'"
    result = cluster.query(query)
    result.rows.first['count']
  end

  def self.find(id)
    cluster = Rails.application.config.couchbase_cluster
    query = "SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE META().id = $1 AND `type` = 'tag'"
    result = cluster.query(query, [id])
    Tag.new(result.rows.first) if result.rows.any?
  end

  def validate!
    raise ActiveModel::ValidationError, self if invalid?
  end
end
