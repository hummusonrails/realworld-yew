# frozen_string_literal: true

require 'couchbase'
include Couchbase
require 'dotenv'
Dotenv.load

# options = Cluster::ClusterOptions.new
# options.authenticate(ENV['COUCHBASE_USERNAME'], ENV['COUCHBASE_PASSWORD'])
# options.apply_profile("wan_development")

cluster = Cluster.connect(ENV['COUCHBASE_URL'], ENV['COUCHBASE_USERNAME'], ENV['COUCHBASE_PASSWORD'])

Rails.application.config.couchbase_cluster = cluster
Rails.application.config.couchbase_bucket = cluster.bucket(ENV['COUCHBASE_BUCKET'])
