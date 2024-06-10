require 'rails_helper'
require 'jwt'

RSpec.describe 'Api::Articles', type: :request do
  let(:headers) { { 'Content-Type': 'application/json' } }
  let(:current_user) do
    User.new(id: 'current-user-id', username: 'currentuser', email: 'currentuser@example.com',
             password_digest: BCrypt::Password.create('password'), bio: 'Current user bio', image: 'current_image.png')
  end
  let(:article_data) do
    {
      '_default' => {
        'id' => 'article-id',
        'slug' => 'test-title',
        'title' => 'Test Title',
        'description' => 'Test Description',
        'body' => 'Test Body',
        'author_id' => current_user.id,
        'created_at' => Time.now,
        'updated_at' => Time.now,
        'type' => 'article',
        'favorites_count' => 0
      },
      'id' => 'article-id'
    }
  end
  let(:updated_attributes) { { title: 'Updated Title' } }
  let(:article) { Article.new(article_data['_default'].merge('id' => article_data['id'])) }
  let(:new_article) do
    Article.new(id: 'new-article-id', title: 'New Article', description: 'New Description', body: 'New Body',
                tag_list: %w[tag1 tag2], author_id: current_user.id, slug: 'new-article')
  end
  let(:token) { JWT.encode({ user_id: current_user.id }, Rails.application.secret_key_base) }
  let(:options) do
    instance_double(Couchbase::Options::Query, positional_parameters: ['test-title'])
  end
  let(:query_result) do
    instance_double(Couchbase::Cluster::QueryResult, rows: [article.to_hash.merge('_default' => article.to_hash)])
  end

  before do
    mock_couchbase_methods

    allow(Couchbase::Options::Query).to receive(:new).and_return(options)
    allow(User).to receive(:find).with(current_user.id).and_return(current_user)
    allow(User).to receive(:find_by_email).and_return(current_user)
    allow(JWT).to receive(:decode).and_return([{ 'user_id' => current_user.id }])
    allow(mock_cluster).to receive(:query).with(
      'SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `slug` = ? AND `author_id` = ? LIMIT 1', options
    ).and_return(query_result)
    allow(mock_collection).to receive(:upsert)
    allow(mock_collection).to receive(:remove)
  end

  describe 'GET /api/articles' do
    it 'returns all articles' do
      allow(Article).to receive(:all).and_return([article])
      headers = { 'Content-Type': 'application/json' }

      get('/api/articles', headers:)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['articles'].first['title']).to eq('Test Title')
    end
  end

  describe 'GET /api/articles/:slug' do
    it 'returns the article' do
      allow(Article).to receive(:find_by_slug).with('test-title').and_return(article)
      headers = { 'Content-Type': 'application/json' }

      get('/api/articles/test-title', headers:)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['article']['title']).to eq('Test Title')
    end

    it 'returns an error if the article is not found' do
      allow(Article).to receive(:find_by_slug).with('unknown-title').and_return(nil)
      headers = { 'Content-Type': 'application/json' }
      get('/api/articles/unknown-title', headers:)

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['errors']).to include('Article not found')
    end
  end

  describe 'POST /api/articles' do
    it 'creates a new article' do
      allow(Article).to receive(:new).and_return(new_article)
      allow(new_article).to receive(:save).and_return(true)
      headers = {
        'Content-Type': 'application/json',
        'Authorization': "Bearer #{token}"
      }

      post('/api/articles',
           params: { article: { title: 'New Article', description: 'New Description', body: 'New Body', tag_list: %w[tag1 tag2] } }.to_json, headers:)

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['article']['title']).to eq('New Article')
    end

    it 'returns an error if the article cannot be created' do
      allow(Article).to receive(:new).and_return(new_article)
      allow(new_article).to receive(:save).and_return(false)
      allow(new_article).to receive_message_chain(:errors, :full_messages).and_return(['Error message'])
      headers = {
        'Content-Type': 'application/json',
        'Authorization': "Bearer #{token}"
      }

      post('/api/articles',
           params: { article: { title: 'New Article', description: 'New Description', body: 'New Body', tag_list: %w[tag1 tag2] } }.to_json, headers:)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors']).to include('Error message')
    end
  end

  describe 'PUT /api/articles/:slug' do
    let(:updated_attributes) { { title: 'Updated Title' } }

    it 'updates the article' do
      allow(mock_collection).to receive(:upsert).and_return(true)
      allow(mock_cluster).to receive(:query).with(
        'SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `slug` = ? AND `author_id` = ? LIMIT 1', anything
      ).and_return(query_result)
      allow(article).to receive(:update).and_call_original
      allow(Article).to receive(:find_by_slug).and_return(article)

      headers = {
        'Content-Type': 'application/json',
        'Authorization': "Bearer #{token}"
      }

      put('/api/articles/test-title', params: { article: updated_attributes }.to_json, headers:)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['article']['title']).to eq('Updated Title')
    end

    it 'returns an error if the article cannot be updated' do
      allow(current_user).to receive(:find_article_by_slug).with('test-title').and_return(article)
      allow(article).to receive(:update).and_return(false)
      allow(article).to receive_message_chain(:errors, :full_messages).and_return(['Error message'])
      headers = {
        'Content-Type': 'application/json',
        'Authorization': "Bearer #{token}"
      }

      put('/api/articles/test-title', params: { article: updated_attributes }.to_json, headers:)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors']).to include('Error message')
    end
  end

  describe 'DELETE /api/articles/:slug' do
    it 'deletes the article' do
      allow(Article).to receive(:find_by_slug).with('test-title').and_return(article)
      allow(article).to receive(:destroy).and_return(true)

      headers = {
        'Content-Type': 'application/json',
        'Authorization': "Bearer #{token}"
      }

      delete('/api/articles/test-title', headers:)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['message']).to eq('Article deleted successfully')
    end

    it 'returns an error if the article cannot be deleted' do
      allow(Article).to receive(:find_by_slug).with('test-title').and_return(article)
      allow(article).to receive(:destroy).and_return(false)
      current_user.id = '12345'
      headers = {
        'Content-Type': 'application/json',
        'Authorization': "Bearer #{token}"
      }

      delete('/api/articles/test-title', headers:)

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['errors']).to include('You are not authorized to delete this article')
    end
  end

  describe 'POST /api/articles/:slug/favorite' do
    it 'favorites the article' do
      allow(Article).to receive(:find_by_slug).with('test-title').and_return(article)
      allow(current_user).to receive(:favorite).with(article).and_return(true)
      headers = {
        'Content-Type': 'application/json',
        'Authorization': "Bearer #{token}"
      }

      post('/api/articles/test-title/favorite', headers:)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['article']['title']).to eq('Test Title')
    end
  end

  describe 'DELETE /api/articles/:slug/unfavorite' do
    it 'unfavorites the article' do
      allow(Article).to receive(:find_by_slug).with('test-title').and_return(article)
      allow(current_user).to receive(:unfavorite).with(article).and_return(true)
      headers = {
        'Content-Type': 'application/json',
        'Authorization': "Bearer #{token}"
      }

      delete('/api/articles/test-title/unfavorite', headers:)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['article']['title']).to eq('Test Title')
    end
  end

  describe 'GET /api/articles/feed' do
    it 'returns the user feed' do
      allow(current_user).to receive(:feed).and_return([article])
      headers = {
        'Content-Type': 'application/json',
        'Authorization': "Bearer #{token}"
      }

      get('/api/articles/feed', headers:)
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['articles'].first['title']).to eq('Test Title')
    end
  end
end
