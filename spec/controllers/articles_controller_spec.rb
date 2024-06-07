require 'rails_helper'
require 'couchbase'
require 'jwt'

RSpec.describe ArticlesController, type: :controller do
  let(:current_user) { User.new(id: 'user-id', username: 'testuser', email: 'test@example.com', password_digest: BCrypt::Password.create('password'), bio: 'Test bio', image: 'default_profile.png') }
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
        'type' => 'article'
      },
      'id' => 'article-id'
    }
  end
  let(:article) { Article.new(article_data['_default'].merge('id' => article_data['id'])) }
  let(:comment_data) do
    {
      '_default' => {
        'id' => 'comment-id',
        'body' => 'Test Comment',
        'article_id' => article.id,
        'author_id' => current_user.id,
        'created_at' => Time.now,
        'updated_at' => Time.now,
        'type' => 'comment'
      },
      'id' => 'comment-id'
    }
  end
  let(:comment) { Comment.new(comment_data['_default'].merge('id' => comment_data['id'])) }
  let(:tag_data) do
    [
      {
        '_default' => {
          'name' => 'tag1',
          'type' => 'tag'
        },
        'id' => '1'
      },
      {
        '_default' => {
          'name' => 'tag2',
          'type' => 'tag'
        },
        'id' => '2'
      }
    ]
  end
  let(:tags) { tag_data.map { |data| Tag.new(data['_default'].merge('id' => data['id'])) } }
  let(:updated_attributes) { { title: 'Updated Title' } }
  let(:token) { JWT.encode({ user_id: current_user.id }, Rails.application.secret_key_base) }
  let(:cluster) { instance_double(Couchbase::Cluster) }
  let(:bucket) { instance_double(Couchbase::Bucket) }
  let(:collection) { instance_double(Couchbase::Collection) }
  let(:query_result_article) { instance_double(Couchbase::Cluster::QueryResult, rows: [article.to_hash.merge('_default' => article.to_hash)]) }
  let(:query_result_articles) { instance_double(Couchbase::Cluster::QueryResult, rows: [article.to_hash.merge('_default' => article.to_hash)]) }
  let(:query_result_comments) { instance_double(Couchbase::Cluster::QueryResult, rows: [comment.to_hash.merge('_default' => comment.to_hash)]) }
  let(:get_result) { instance_double(Couchbase::Collection::GetResult, content: current_user.to_hash) }
  let(:errors) { double('errors', any?: true, full_messages: ['Error message']) }
  let(:lookup_in_result) { instance_double(Couchbase::Collection::LookupInResult, content: [], exists?: true) }
  let(:mutate_in) { instance_double(Couchbase::Collection::MutateInSpec) }

  before do
    allow(Rails.application.config).to receive(:couchbase_cluster).and_return(cluster)
    allow(Rails.application.config).to receive(:couchbase_bucket).and_return(bucket)
    allow(bucket).to receive(:default_collection).and_return(collection)
    allow(Tag).to receive(:all).and_return(tags)
    allow(Article).to receive(:all).and_return([article])
    allow(User).to receive(:find).and_return(current_user)
    allow(JWT).to receive(:decode).and_return([{ 'user_id' => current_user.id }])
    allow(controller).to receive(:current_user).and_return(current_user)
    allow(controller).to receive(:authenticate_user).and_return(true)
    allow(cluster).to receive(:query).with("SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `slug` = ? AND `author_id` = ? LIMIT 1", an_instance_of(Couchbase::Options::Query)).and_return(query_result_article)
    allow(cluster).to receive(:query).with("SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `type` = 'article' AND `author_id` = ?", an_instance_of(Couchbase::Options::Query)).and_return(query_result_articles)
    allow(cluster).to receive(:query).with("SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `type` = 'comment' AND `article_id` = ?", an_instance_of(Couchbase::Options::Query)).and_return(query_result_comments)
    allow(collection).to receive(:upsert)
    allow(collection).to receive(:remove)
    allow(collection).to receive(:lookup_in).with(current_user.id, anything).and_return(lookup_in_result)
    allow(collection).to receive(:mutate_in).with(current_user.id, anything).and_return(mutate_in)
    request.headers['Authorization'] = "Bearer #{token}"
    stub_image_tag
  end

  describe 'GET #index' do
    it 'returns all articles' do
      allow(collection).to receive(:get).with(current_user.id).and_return(get_result)
      allow(cluster).to receive(:query).and_return(query_result_articles)
      allow(User).to receive(:find).with('user-id').and_return(current_user)

      get :index

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Test Title')
    end
  end


  describe 'GET #show' do
    it 'returns the requested article' do
      allow(Article).to receive(:find_by_slug).with('test-title').and_return(article)

      get :show, params: { id: 'test-title' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Test Title')
    end
  end

  describe 'POST #create' do
    context 'when authenticated' do
      it 'creates a new article' do
        allow(Article).to receive(:new).and_return(article)
        allow(article).to receive(:save).and_return(true)

        post :create, params: { article: { title: 'Test Title', description: 'Test Description', body: 'Test Body', tagList: ['tag1', 'tag2'] } }

        expect(response).to have_http_status(:found)
        expect(flash[:notice]).to eq('Article created successfully.')
      end

      it 'returns an error if the article cannot be created' do
        allow(Article).to receive(:new).and_return(article)
        allow(article).to receive(:save).and_return(false)
        allow(article).to receive(:errors).and_return(errors)

        post :create, params: { article: { title: 'Test Title', description: 'Test Description', body: 'Test Body', tag_list: ['tag1', 'tag2'] } }

        expect(response).to have_http_status(:ok)
        expect(flash[:alert]).to eq('There were errors saving your article.')
      end
    end

    context 'when not authenticated' do
      it 'returns an error' do
        request.headers['Authorization'] = nil

        post :create, params: { article: { title: 'Test Title', description: 'Test Description', body: 'Test Body', tag_list: ['tag1', 'tag2'] } }

        expect(response).to have_http_status(:ok)
        expect(flash[:alert]).to eq('There were errors saving your article.')
      end
    end
  end

  describe 'PUT #update' do
    context 'when authenticated' do
      it 'updates the article' do
        allow(collection).to receive(:get).with(current_user.id).and_return(get_result)
        allow(collection).to receive(:upsert).and_return(true)

        allow(cluster).to receive(:query).with("SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `slug` = ? AND `author_id` = ? LIMIT 1", anything).and_return(query_result_article)

        allow(article).to receive(:update).and_call_original

        allow(Article).to receive(:find_by_slug).and_return(article)

        put :update, params: { id: 'test-title', article: updated_attributes }, as: :json

        expect(response).to have_http_status(:found)
        expect(flash[:notice]).to eq('Article updated successfully.')
      end

      it 'returns an error if the article cannot be updated' do
        allow(collection).to receive(:get).with(current_user.id).and_return(get_result)
        allow(cluster).to receive(:query).with("SELECT META().id, * FROM RealWorldRailsBucket.`_default`.`_default` WHERE `slug` = ? AND `author_id` = ? LIMIT 1", anything).and_return(query_result_article)

        allow(collection).to receive(:upsert).and_return(false)

        allow(article).to receive(:update).and_return(false)
        allow(article).to receive_message_chain(:errors, :full_messages).and_return(['Error message'])

        allow(Article).to receive(:find_by_slug).and_return(article)

        put :update, params: { id: 'test-title', article: { title: 'Not working'} }

        expect(response).to have_http_status(:found)
        expect(flash[:alert]).to eq('There were errors updating your article.')
      end
    end

    context 'when not authenticated' do
      it 'returns an error' do
        request.headers['Authorization'] = nil
        session[:user_id] = nil

        put :update, params: { id: 'test-title', article: { title: 'Updated Title' } }

        expect(response).to have_http_status(:found)
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when authenticated' do
      it 'deletes the article' do
        allow(Article).to receive(:find_by_slug).with('test-title').and_return(article)
        allow(article).to receive(:destroy).and_return(true)

        delete :destroy, params: { id: 'test-title' }

        expect(response).to have_http_status(:found)
      end
    end

    context 'when not authenticated' do
      it 'returns an error' do
        allow(Article).to receive(:find_by_slug).with('test-title').and_return(article)
        allow(article).to receive(:destroy).and_return(false)

        request.headers['Authorization'] = nil
        session[:user_id] = nil

        delete :destroy, params: { id: 'test-title' }

        expect(response).to have_http_status(:found)
      end
    end
  end

  describe 'GET #feed' do
    context 'when authenticated' do
      it 'returns the user feed' do
        allow(collection).to receive(:get).with(current_user.id).and_return(get_result)
        allow(current_user).to receive(:feed).and_return([article])

        get :feed, as: :json

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['articles'].first['title']).to eq('Test Title')
      end
    end

    context 'when not authenticated' do
      it 'returns an error' do
        allow(current_user).to receive(:feed).and_return([])
        request.headers['Authorization'] = nil

        get :feed, as: :json

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'POST #favorite' do
    context 'when authenticated' do
      it 'favorites the article' do
        allow(Article).to receive(:find_by_slug).with('test-title').and_return(article)
        allow(current_user).to receive(:favorite).with(article).and_return(true)

        post :favorite, params: { id: 'test-title' }, as: :json

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['article']['title']).to eq('Test Title')
      end
    end
  end

  describe 'DELETE #unfavorite' do
    context 'when authenticated' do
      it 'unfavorites the article' do
        allow(Article).to receive(:find_by_slug).with('test-title').and_return(article)
        allow(current_user).to receive(:unfavorite).with(article).and_return(true)

        delete :unfavorite, params: { id: 'test-title' }

        expect(response).to have_http_status(:found)
      end
    end
  end
end
