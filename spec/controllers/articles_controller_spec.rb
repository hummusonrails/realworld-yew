require 'rails_helper'
require 'couchbase'
require 'jwt'

RSpec.describe ArticlesController, type: :controller do
  let(:current_user) { User.new(id: 'user-id', username: 'testuser', email: 'test@example.com', password_digest: BCrypt::Password.create('password'), bio: 'Test bio', image: 'test_image.png') }
  let(:article) { Article.new(id: 'article-id', slug: 'test-title', title: 'Test Title', description: 'Test Description', body: 'Test Body', author_id: current_user.id) }
  let(:updated_attributes) { { title: 'Updated Title' } }
  let(:token) { JWT.encode({ user_id: current_user.id }, Rails.application.secret_key_base) }
  let(:cluster) { instance_double(Couchbase::Cluster) }
  let(:bucket) { instance_double(Couchbase::Bucket) }
  let(:collection) { instance_double(Couchbase::Collection) }
  let(:query_result) { instance_double(Couchbase::Cluster::QueryResult, rows: [article.to_hash]) }
  let(:get_result) { instance_double(Couchbase::Collection::GetResult, content: current_user.to_hash) }

  before do
    allow(Rails.application.config).to receive(:couchbase_cluster).and_return(cluster)
    allow(Rails.application.config).to receive(:couchbase_bucket).and_return(bucket)
    allow(bucket).to receive(:default_collection).and_return(collection)
    allow(User).to receive(:find).and_return(current_user)
    allow(JWT).to receive(:decode).and_return([{ 'user_id' => current_user.id }])
    request.headers['Authorization'] = "Bearer #{token}"
  end

  describe 'GET #index' do
  it 'returns all articles' do
    allow(collection).to receive(:get).with(current_user.id).and_return(get_result)
    allow(cluster).to receive(:query).and_return(query_result)

    get :index
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['articles'].first['title']).to eq('Test Title')
  end
  end

  describe 'GET #show' do
    it 'returns the requested article' do
      allow(Article).to receive(:find_by_slug).with('test-title').and_return(article)

      get :show, params: { id: 'test-title' }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['article']['title']).to eq('Test Title')
    end
  end

  describe 'POST #create' do
    context 'when authenticated' do
      it 'creates a new article' do
        allow(Article).to receive(:new).and_return(article)
        allow(article).to receive(:save).and_return(true)

        post :create, params: { article: { title: 'Test Title', description: 'Test Description', body: 'Test Body', tagList: ['tag1', 'tag2'] } }

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)['article']['title']).to eq('Test Title')
      end

      it 'returns an error if the article cannot be created' do
        allow(Article).to receive(:new).and_return(article)
        allow(article).to receive(:save).and_return(false)
        allow(article).to receive_message_chain(:errors, :full_messages).and_return(['Error message'])

        post :create, params: { article: { title: 'Test Title', description: 'Test Description', body: 'Test Body', tagList: ['tag1', 'tag2'] } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to include('Error message')
      end
    end

    context 'when not authenticated' do
      it 'returns an error' do
        request.headers['Authorization'] = nil

        post :create, params: { article: { title: 'Test Title', description: 'Test Description', body: 'Test Body', tagList: ['tag1', 'tag2'] } }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors']).to include('Not Authenticated')
      end
    end
  end

  describe 'PUT #update' do
  context 'when authenticated' do
    it 'updates the article' do
      allow(collection).to receive(:get).with(current_user.id).and_return(get_result)
      allow(collection).to receive(:upsert).and_return(true)

      allow(cluster).to receive(:query).with("SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `slug` = ? AND `author_id` = ? LIMIT 1", anything).and_return(query_result)

      allow(article).to receive(:update).and_call_original

      allow(Article).to receive(:find_by_slug).and_return(article)

      put :update, params: { id: 'test-title', article: updated_attributes }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['article']['title']).to eq('Updated Title')
    end

    it 'returns an error if the article cannot be updated' do
      allow(collection).to receive(:get).with(current_user.id).and_return(get_result)
      allow(cluster).to receive(:query).with("SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `slug` = ? AND `author_id` = ? LIMIT 1", anything).and_return(query_result)

      allow(collection).to receive(:upsert).and_return(false)

      allow(article).to receive(:update).and_return(false)
      allow(article).to receive_message_chain(:errors, :full_messages).and_return(['Error message'])

      allow(Article).to receive(:find_by_slug).and_return(article)

      put :update, params: { id: 'test-title', article: { title: 'Not working'} }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  context 'when not authenticated' do
    it 'returns an error' do
      request.headers['Authorization'] = nil

      put :update, params: { id: 'test-title', article: updated_attributes }

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)['errors']).to include('Not Authenticated')
    end
  end
end

  describe 'DELETE #destroy' do
    context 'when authenticated' do
      it 'deletes the article' do
        allow(current_user).to receive_message_chain(:articles, :find_by_slug).and_return(article)
        allow(article).to receive(:destroy).and_return(true)

        delete :destroy, params: { id: 'test-title' }

        expect(response).to have_http_status(:no_content)
      end
    end

    context 'when not authenticated' do
      it 'returns an error' do
        request.headers['Authorization'] = nil

        delete :destroy, params: { id: 'test-title' }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors']).to include('Not Authenticated')
      end
    end
  end

  describe 'GET #feed' do
    context 'when authenticated' do
      it 'returns the user feed' do
        allow(collection).to receive(:get).with(current_user.id).and_return(get_result)
        allow(current_user).to receive(:feed).and_return([article])

        get :feed

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['articles'].first['title']).to eq('Test Title')
      end
    end

    context 'when not authenticated' do
      it 'returns an error' do
        request.headers['Authorization'] = nil

        get :feed

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors']).to include('Not Authenticated')
      end
    end
  end

  describe 'POST #favorite' do
    context 'when authenticated' do
      it 'favorites the article' do
        allow(Article).to receive(:find_by_slug).with('test-title').and_return(article)
        allow(current_user).to receive(:favorite).with(article).and_return(true)

        post :favorite, params: { id: 'test-title' }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['article']['title']).to eq('Test Title')
      end
    end

    context 'when not authenticated' do
      it 'returns an error' do
        request.headers['Authorization'] = nil

        post :favorite, params: { id: 'test-title' }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors']).to include('Not Authenticated')
      end
    end
  end

  describe 'DELETE #unfavorite' do
    context 'when authenticated' do
      it 'unfavorites the article' do
        allow(Article).to receive(:find_by_slug).with('test-title').and_return(article)
        allow(current_user).to receive(:unfavorite).with(article).and_return(true)

        delete :unfavorite, params: { id: 'test-title' }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['article']['title']).to eq('Test Title')
      end
    end

    context 'when not authenticated' do
      it 'returns an error' do
        request.headers['Authorization'] = nil

        delete :unfavorite, params: { id: 'test-title' }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors']).to include('Not Authenticated')
      end
    end
  end
end
