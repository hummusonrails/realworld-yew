require 'rails_helper'
require 'couchbase'

RSpec.describe Tag, type: :model do
  let(:tag) { Tag.new(id: 'tag-id', name: 'Example Tag', type: 'tag') }

  let(:bucket) { instance_double(Couchbase::Bucket) }
  let(:collection) { instance_double(Couchbase::Collection) }
  let(:cluster) { instance_double(Couchbase::Cluster) }
  let(:query_result) { instance_double(Couchbase::Cluster::QueryResult, rows: [{'count' => 0}]) }

  before do
    allow(Rails.application.config).to receive(:couchbase_bucket).and_return(bucket)
    allow(Rails.application.config).to receive(:couchbase_cluster).and_return(cluster)
    allow(bucket).to receive(:default_collection).and_return(collection)
  end

  describe '#save' do
    context 'when saving a new tag' do
      it 'creates a new tag in the database' do
        allow(collection).to receive(:upsert).with(tag.id, hash_including(
          'name' => 'Example Tag',
          'type' => 'tag'
        ))

        tag.save

        expect(tag.id).to eq('tag-id')
      end
    end

    context 'when updating an existing tag' do
      it 'updates the tag in the database' do
        allow(collection).to receive(:upsert).with(tag.id, hash_including(
          'name' => 'Example Tag',
          'type' => 'tag'
        ))
        tag.save

        tag.name = 'Updated Tag'
        allow(collection).to receive(:upsert).with(tag.id, hash_including(
          'name' => 'Updated Tag',
          'type' => 'tag'
        ))
        tag.save

        allow(cluster).to receive(:query).with("SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE META().id = $1 AND `type` = 'tag'", [tag.id]).and_return(instance_double(Couchbase::Cluster::QueryResult, rows: [tag.to_hash]))

        expect(Tag.find(tag.id).name).to eq('Updated Tag')
      end
    end

    context 'when name is missing' do
      it 'raises an error' do
        tag = Tag.new(type: 'tag')
        expect { tag.save }.to raise_error(ActiveModel::ValidationError)
      end
    end
  end

  describe '#to_hash' do
    it 'returns a hash with name and type' do
      expect(tag.to_hash).to eq({ 'name' => 'Example Tag', 'type' => 'tag' })
    end
  end
end
