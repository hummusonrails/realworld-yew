# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Comments', type: :request do
  let(:headers) { { 'Content-Type': 'application/json' } }
  let(:current_user) { User.new(id: 'current-user-id', username: 'currentuser', email: 'currentuser@example.com', password_digest: BCrypt::Password.create('password'), bio: 'Current user bio', image: 'current_image.png') }
  let(:article) { Article.new(id: 'article-id', title: 'Test Title', description: 'Test Description', body: 'Test Body', tag_list: ['tag1', 'tag2'], author_id: current_user.id, slug: 'test-title') }
  let(:comment) { Comment.new(id: 'comment-id', body: 'Test Comment', author_id: current_user.id, article_id: article.id, type: 'comment') }
  let(:token) { JWT.encode({ user_id: current_user.id }, Rails.application.secret_key_base) }
  let(:options) do
    instance_double(Couchbase::Options::Query, positional_parameters: ['article-id'])
  end
  let(:query_result) do
    instance_double(Couchbase::Cluster::QueryResult, rows: [comment.to_hash.merge('_default' => comment.to_hash)])
  end

  before do
    mock_couchbase_methods

    allow(Couchbase::Options::Query).to receive(:new).and_return(options)
    allow(User).to receive(:find).with(current_user.id).and_return(current_user)
    allow(Article).to receive(:find_by_slug).with(article.slug).and_return(article)
    allow(JWT).to receive(:decode).and_return([{ 'user_id' => current_user.id }])
    allow(mock_cluster).to receive(:query).with(
      "SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `type` = 'comment' AND `article_id` = ?", options
    ).and_return(query_result)
    allow(mock_collection).to receive(:upsert)
    allow(mock_collection).to receive(:remove)
  end

  describe 'GET /api/articles/:slug/comments' do
    it 'returns all comments for the article' do
      allow(article).to receive(:comments).and_return([comment])

      get "/api/articles/#{article.slug}/comments", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['comments'].first['body']).to eq('Test Comment')
    end

    it 'returns an error if the article is not found' do
      allow(Article).to receive(:find_by_slug).with('unknown-slug').and_return(nil)

      get "/api/articles/unknown-slug/comments", headers: headers

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['errors']).to include('Article not found')
    end
  end

  describe 'POST /api/articles/:slug/comments' do
    context 'when authenticated' do
      it 'creates a new comment for the article' do
        allow(article).to receive(:add_comment).and_return(comment)
        allow_any_instance_of(Comment).to receive(:save).and_return(true)

        post "/api/articles/#{article.slug}/comments", params: { comment: { body: 'Test Comment' } }.to_json, headers: headers.merge('Authorization': "Bearer #{token}")

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)['comment']['body']).to eq('Test Comment')
      end

      it 'returns an error if the comment cannot be created' do
        allow(article).to receive(:add_comment).and_return(comment)
        allow_any_instance_of(Comment).to receive(:save).and_return(false)
        allow_any_instance_of(Comment).to receive_message_chain(:errors, :full_messages).and_return(['Error message'])

        post "/api/articles/#{article.slug}/comments", params: { comment: { body: 'Test Comment' } }.to_json, headers: headers.merge('Authorization': "Bearer #{token}")

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to include('Error message')
      end
    end

    context 'when not authenticated' do
      it 'returns an error' do
        post "/api/articles/#{article.slug}/comments", params: { comment: { body: 'Test Comment' } }.to_json, headers: headers

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors']).to include('Not Authenticated')
      end
    end

    it 'returns an error if the article is not found' do
      allow(Article).to receive(:find_by_slug).with('unknown-slug').and_return(nil)

      post "/api/articles/unknown-slug/comments", params: { comment: { body: 'Test Comment' } }.to_json, headers: headers.merge('Authorization': "Bearer #{token}")

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['errors']).to include('Article not found')
    end
  end

  describe 'DELETE /api/articles/:slug/comments/:id' do
    context 'when authenticated' do
      it 'deletes the comment' do
        allow(Comment).to receive(:find).with(comment.id).and_return(comment)
        allow(comment).to receive(:destroy).and_return(true)

        delete "/api/articles/#{article.slug}/comments/#{comment.id}", headers: headers.merge('Authorization': "Bearer #{token}")

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['message']).to eq('Comment deleted successfully')
      end
    end

    context 'when not authenticated' do
      it 'returns an error' do
        delete "/api/articles/#{article.slug}/comments/#{comment.id}", headers: headers

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors']).to include('Not Authenticated')
      end
    end

    it 'returns an error if the article is not found' do
      allow(Article).to receive(:find_by_slug).with('unknown-slug').and_return(nil)
      allow(comment).to receive(:destroy).and_return(false)

      delete "/api/articles/unknown-slug/comments/#{comment.id}", headers: headers.merge('Authorization': "Bearer #{token}")

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['errors']).to include('Article not found')
    end

    it 'returns an error if the comment is not found' do
      allow(Article).to receive(:find_by_slug).with(article.slug).and_return(article)
      allow(Comment).to receive(:find).and_return(nil)

      delete "/api/articles/#{article.slug}/comments/unknown-id", headers: headers.merge('Authorization': "Bearer #{token}")

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['errors']).to include('Comment not found')
    end
  end
end
