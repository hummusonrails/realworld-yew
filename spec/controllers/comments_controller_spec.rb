require 'rails_helper'
require 'couchbase'
require 'jwt'

RSpec.describe CommentsController, type: :controller do
  let(:user) { User.new(id: 'user-id', username: 'testuser', email: 'test@example.com', password_digest: BCrypt::Password.create('password')) }
  let(:article) { Article.new(id: 'test-title', title: 'Test Title', description: 'Test Description', body: 'Test Body', tag_list: 'tag1,tag2', author_id: user.id) }
  let(:comment) { Comment.new(id: 'comment-id', body: 'Test Comment', author_id: user.id, article_id: article.id, type: 'comment') }
  let(:token) { JWT.encode({ user_id: user.id }, Rails.application.secret_key_base) }

  let(:bucket) { instance_double(Couchbase::Bucket) }
  let(:collection) { instance_double(Couchbase::Collection) }
  let(:cluster) { instance_double(Couchbase::Cluster) }
  let(:query_result_user) { instance_double(Couchbase::Cluster::QueryResult, rows: [user.to_hash]) }
  let(:query_result_comment) { instance_double(Couchbase::Cluster::QueryResult, rows: [comment.to_hash]) }
  let(:get_result) { instance_double(Couchbase::GetResult, content: user.to_hash) }

  before do
    allow(Rails.application.config).to receive(:couchbase_bucket).and_return(bucket)
    allow(Rails.application.config).to receive(:couchbase_cluster).and_return(cluster)
    allow(bucket).to receive(:default_collection).and_return(collection)

    allow(collection).to receive(:upsert)

    allow(JWT).to receive(:decode).and_return([{ 'user_id' => user.id }])
    request.headers['Authorization'] = "Bearer #{token}"

    allow(cluster).to receive(:query).with("SELECT META().id, * FROM `realworld-rails` WHERE `type` = 'user' AND `id` = $1 LIMIT 1", anything).and_return(query_result_user)
    allow(cluster).to receive(:query).with("SELECT META().id, * FROM `realworld-rails` WHERE `type` = 'comment' AND `id` = $1 LIMIT 1", anything).and_return(query_result_comment)
  end

  describe 'GET #index' do
    it 'returns all comments for the article' do
      allow(Article).to receive(:find_by_slug).with('test-title').and_return(article)
      allow(article).to receive(:comments).and_return([comment])

      get :index, params: { article_id: 'test-title' }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['comments'].first['body']).to eq('Test Comment')
    end
  end

  describe 'POST #create' do
    context 'when authenticated' do
      it 'creates a new comment for the article' do
        allow(Article).to receive(:find_by_slug).with('test-title').and_return(article)
        allow(article).to receive(:add_comment).with(instance_of(Comment)).and_return(true)
        allow_any_instance_of(Comment).to receive(:save).and_return(true)

        post :create, params: { article_id: 'test-title', comment: { body: 'Test Comment' } }

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)['comment']['body']).to eq('Test Comment')
      end

      it 'returns an error if the comment cannot be created' do
        allow(Article).to receive(:find_by_slug).with('test-title').and_return(article)
        allow(article).to receive(:add_comment).with(instance_of(Comment)).and_return(true)
        allow_any_instance_of(Comment).to receive(:save).and_return(false)
        allow_any_instance_of(Comment).to receive_message_chain(:errors, :full_messages).and_return(['Error message'])

        post :create, params: { article_id: 'test-title', comment: { body: 'Test Comment' } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to include('Error message')
      end
    end

    context 'when not authenticated' do
      it 'returns an error' do
        request.headers['Authorization'] = nil

        post :create, params: { article_id: 'test-title', comment: { body: 'Test Comment' } }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors']).to include('Not Authenticated')
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when authenticated' do
      it 'deletes the comment' do
        allow(Article).to receive(:find_by_slug).with('test-title').and_return(article)
        allow(Comment).to receive(:find).with('comment-id').and_return(comment)
        allow(collection).to receive(:remove).with('comment-id').and_return(true)

        delete :destroy, params: { article_id: 'article-id', id: 'comment-id' }

        expect(response).to have_http_status(:no_content)
      end
    end

    context 'when not authenticated' do
      it 'returns an error' do
        request.headers['Authorization'] = nil

        delete :destroy, params: { article_id: 'article-id', id: 'comment-id' }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors']).to include('Not Authenticated')
      end
    end
  end
end
