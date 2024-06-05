require 'rails_helper'
require 'couchbase'

RSpec.describe TagsController, type: :controller do
  let(:tag) { Tag.new(name: 'Example Tag', type: 'tag') }
  let(:bucket) { instance_double(Couchbase::Bucket) }
  let(:collection) { instance_double(Couchbase::Collection) }
  let(:query_result) { instance_double(Couchbase::Cluster::QueryResult, rows: [tag.to_hash]) }
  let(:cluster) { instance_double(Couchbase::Cluster) }

  before do
    allow(Rails.application.config).to receive(:couchbase_bucket).and_return(bucket)
    allow(Rails.application.config).to receive(:couchbase_cluster).and_return(cluster)
    allow(bucket).to receive(:default_collection).and_return(collection)
  end

  describe 'GET #index' do
    it 'returns all tags' do
      allow(cluster).to receive(:query).with("SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `type` = 'tag'").and_return(query_result)

      get :index

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['tags']).to include('Example Tag')
    end
  end
end
