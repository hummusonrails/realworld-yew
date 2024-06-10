require 'rails_helper'
require 'couchbase'

RSpec.describe Tag, type: :model do
  let(:tag) { Tag.new(id: 'tag-id', name: 'Example Tag', type: 'tag') }

  before do
    mock_couchbase_methods

    allow(Tag).to receive(:find).with('tag-id').and_return(tag)
    allow(mock_collection).to receive(:upsert)
    allow(mock_cluster).to receive(:query).and_return(instance_double(Couchbase::Cluster::QueryResult,
                                                                      rows: [tag.to_hash]))
  end

  describe '#save' do
    context 'when saving a new tag' do
      it 'creates a new tag in the database' do
        allow(mock_collection).to receive(:upsert).with(tag.id, hash_including(
                                                                  'name' => 'Example Tag',
                                                                  'type' => 'tag'
                                                                ))

        tag.save

        expect(tag.id).to eq('tag-id')
      end
    end

    context 'when updating an existing tag' do
      it 'updates the tag in the database' do
        allow(mock_collection).to receive(:upsert).with(tag.id, hash_including(
                                                                  'name' => 'Example Tag',
                                                                  'type' => 'tag'
                                                                ))
        tag.save

        tag.name = 'Updated Tag'
        allow(mock_collection).to receive(:upsert).with(tag.id, hash_including(
                                                                  'name' => 'Updated Tag',
                                                                  'type' => 'tag'
                                                                ))
        tag.save

        allow(mock_cluster).to receive(:query).with(
          "SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE META().id = $1 AND `type` = 'tag'", [tag.id]
        ).and_return(instance_double(
                       Couchbase::Cluster::QueryResult, rows: [tag.to_hash]
                     ))

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
