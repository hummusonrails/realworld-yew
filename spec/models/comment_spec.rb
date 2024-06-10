require 'rails_helper'
require 'couchbase'

RSpec.describe Comment, type: :model do
  let(:bucket) { instance_double(Couchbase::Bucket) }
  let(:collection) { instance_double(Couchbase::Collection) }
  let(:cluster) { instance_double(Couchbase::Cluster) }
  let(:query_result) { instance_double(Couchbase::Cluster::QueryResult, rows: []) }
  let(:author) { User.new(id: 'author-id', username: 'author', email: 'author@example.com') }
  let(:article) do
    Article.new(id: 'article-id', title: 'Test Title', description: 'Test Description', body: 'Test Body',
                tag_list: 'tag1,tag2', author_id: author.id)
  end
  let(:comment) do
    Comment.new(id: 'comment-id', body: 'Test Comment', author_id: 'author-id', article_id: 'article-id',
                type: 'comment')
  end

  before do
    mock_couchbase_methods

    allow(User).to receive(:find).with('author-id').and_return(author)
  end

  describe '#save' do
    context 'when saving a new comment' do
      it 'creates a new comment in the database' do
        allow(mock_collection).to receive(:upsert).with(comment.id, hash_including(
                                                                      'type' => 'comment',
                                                                      'body' => 'Test Comment',
                                                                      'author_id' => 'author-id',
                                                                      'article_id' => 'article-id'
                                                                    ))
        expect { comment.save }.not_to raise_error
      end
    end

    context 'when updating an existing comment' do
      it 'updates the comment in the database' do
        comment.id = 'comment-id'
        allow(mock_collection).to receive(:upsert).with(comment.id, hash_including(
                                                                      'type' => 'comment',
                                                                      'body' => 'Test Comment',
                                                                      'author_id' => 'author-id',
                                                                      'article_id' => 'article-id'
                                                                    ))
        comment.save

        comment.body = 'Updated Comment'
        allow(mock_collection).to receive(:upsert).with(comment.id, hash_including(
                                                                      'type' => 'comment',
                                                                      'body' => 'Updated Comment',
                                                                      'author_id' => 'author-id',
                                                                      'article_id' => 'article-id'
                                                                    ))
        comment.save

        expect(comment.body).to eq('Updated Comment')
      end
    end

    context 'when body is missing' do
      it 'raises an error' do
        invalid_comment = Comment.new(author_id: 'author-id', article_id: 'article-id', type: 'comment')
        expect { invalid_comment.save }.to raise_error(ActiveModel::ValidationError)
      end
    end

    context 'when author_id is missing' do
      it 'raises an error' do
        invalid_comment = Comment.new(body: 'Test Comment', article_id: 'article-id', type: 'comment')
        expect { invalid_comment.save }.to raise_error(ActiveModel::ValidationError)
      end
    end
  end

  describe '#to_hash' do
    it 'returns a hash with the correct attributes' do
      expect(comment.to_hash).to eq({
                                      'type' => 'comment',
                                      'body' => 'Test Comment',
                                      'author_id' => 'author-id',
                                      'created_at' => comment.created_at,
                                      'updated_at' => comment.updated_at,
                                      'article_id' => 'article-id'
                                    })
    end
  end
end
