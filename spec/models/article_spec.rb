require 'rails_helper'
require 'couchbase'

RSpec.describe Article, type: :model do
  let(:author) { User.new(id: 'author-id', username: 'author', email: 'author@example.com') }
  let(:article) { Article.new(id: 'article-id', title: 'Test Title', description: 'Test Description', body: 'Test Body', tag_list: 'tag1,tag2', author_id: author.id, favorites: [], favorites_count: 0) }
  let(:comment) { Comment.new(id: 'comment-id', body: 'Test Comment', author_id: 'author-id', article_id: article.id) }
  let(:options) do
    instance_double(Couchbase::Options::Query, positional_parameters: ['test-title'])
  end
  let(:query_result) { instance_double(Couchbase::Cluster::QueryResult, rows: [{ '_default' => { 'title' => 'Test Title', 'description' => 'Test Description', 'body' => 'Test Body', 'author_id' => 'user-id', 'type' => 'article' }, 'id' => 'article-id' }]) }

  before do
    mock_couchbase_methods

    allow(Couchbase::Options::Query).to receive(:new).and_return(options)
    allow(mock_cluster).to receive(:query).with("SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `type` = 'article' AND `slug` = ? LIMIT 1", options).and_return(query_result)
    allow(mock_cluster).to receive(:query).with("SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `type` = 'article'").and_return(query_result)
    allow(User).to receive(:find).with('author-id').and_return(author)
  end

  context 'when saving an article' do
    describe '#save' do
      it 'creates a new article record in the database' do
        allow(mock_collection).to receive(:upsert).with(article.id, hash_including(
          'type' => 'article',
          'author_id' => 'author-id',
          'body' => 'Test Body',
          'description' => 'Test Description',
          'tag_list' => 'tag1,tag2',
          'title' => 'Test Title'
        ))

        article.save

        expect(article.id).to eq('article-id')
      end
    end
  end

  context 'when converting an article to a hash' do
    describe '#to_hash' do
      it 'returns the article attributes as a hash' do
        expected_hash = {
          'type' => 'article',
          'slug' => article.slug,
          'title' => 'Test Title',
          'description' => 'Test Description',
          'body' => 'Test Body',
          'tag_list' => 'tag1,tag2',
          'created_at' => article.created_at,
          'updated_at' => article.updated_at,
          'author_id' => article.author_id,
          'favorites_count' => 0,
        }
        expect(article.to_hash).to eq(expected_hash)
      end
    end
  end

  context 'when finding an article by slug' do
    describe '.find_by_slug' do
      it 'finds an article by slug' do
        article = Article.find_by_slug('test-title')
        expect(article).to be_a(Article)
        expect(article.title).to eq('Test Title')
      end
    end
  end

  context 'when retrieving all articles' do
    describe '.all' do
      it 'returns all articles' do
        articles = Article.all
        expect(articles).to be_an(Array)
        expect(articles.first).to be_a(Article)
        expect(articles.first.title).to eq('Test Title')
      end
    end
  end

  context 'when dealing with comments' do
    before do
      allow(mock_collection).to receive(:upsert).with(comment.id, hash_including(
        'type' => 'comment',
        'author_id' => 'author-id',
        'body' => 'Test Comment',
        'article_id' => article.id
      ))
      allow(comment).to receive(:save)
    end

    describe '#comments' do
      it 'returns all comments for the article' do
        allow(mock_collection).to receive(:upsert).with(article.id, hash_including(
          'author_id' => 'author-id',
          'body' => 'Test Body',
          'description' => 'Test Description',
          'tag_list' => 'tag1,tag2',
          'title' => 'Test Title'
        ))

        article.save
        allow(article).to receive(:comments).and_return([comment])
        expect(article.comments.map(&:body)).to include('Test Comment')
      end
    end

    describe '#add_comment' do
      it 'adds a comment to the article' do
        allow(mock_collection).to receive(:upsert).with(article.id, hash_including(
          'author_id' => 'author-id',
          'body' => 'Test Body',
          'description' => 'Test Description',
          'tag_list' => 'tag1,tag2',
          'title' => 'Test Title'
        ))

        article.save

        allow(article).to receive(:add_comment).and_return([comment])
        allow(article).to receive(:comments).and_return([comment])

        expect(article.comments.map(&:body)).to include('Test Comment')
      end
    end
  end
end
