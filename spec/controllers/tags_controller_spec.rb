# frozen_string_literal: true

require 'rails_helper'
require 'couchbase'

RSpec.describe TagsController, type: :controller do
  let(:tag) { Tag.new(name: 'Example Tag', type: 'tag') }
  let(:bucket) { instance_double(Couchbase::Bucket) }
  let(:collection) { instance_double(Couchbase::Collection) }
  let(:query_result) do
    instance_double(Couchbase::Cluster::QueryResult, rows: [{ '_default' => tag.to_hash.merge('id' => 'tag-id') }])
  end
  let(:cluster) { instance_double(Couchbase::Cluster) }

  before do
    mock_couchbase_methods

    allow(mock_bucket).to receive(:default_collection).and_return(mock_collection)
  end

  describe 'GET #index' do
    it 'returns all tags' do
      allow(mock_cluster).to receive(:query).with("SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `type` = 'tag'").and_return(query_result)

      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['tags']).to include('Example Tag')
    end
  end
end
