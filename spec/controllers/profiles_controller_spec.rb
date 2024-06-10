require 'rails_helper'
require 'couchbase'
require 'jwt'

RSpec.describe ProfilesController, type: :controller do
  let(:current_user) { User.new(id: 'current-user-id', username: 'currentuser', email: 'currentuser@example.com', password_digest: BCrypt::Password.create('password'), bio: 'Current user bio', image: 'current_image.png') }
  let(:other_user) { User.new(id: 'other-user-id', username: 'otheruser', email: 'otheruser@example.com', password_digest: BCrypt::Password.create('password'), bio: 'Other user bio', image: 'other_image.png') }
  let(:bucket) { instance_double(Couchbase::Bucket) }
  let(:collection) { instance_double(Couchbase::Collection) }
  let(:cluster) { instance_double(Couchbase::Cluster) }
  let(:token) { JWT.encode({ user_id: current_user.id }, Rails.application.secret_key_base) }
  let(:lookup_in_result) { instance_double(Couchbase::Collection::LookupInResult, content: [], exists?: true) }

  before do
    allow(User).to receive(:find_by_username).with('currentuser').and_return(current_user)
    allow(User).to receive(:find_by_username).with('otheruser').and_return(other_user)
    allow(User).to receive(:find).with(current_user.id).and_return(current_user)
    allow(collection).to receive(:lookup_in).with(current_user.id, anything).and_return(lookup_in_result)
    allow(collection).to receive(:lookup_in).with(other_user.id, anything).and_return(lookup_in_result)
    allow(collection).to receive(:mutate_in)
    allow(JWT).to receive(:decode).and_return([{ 'user_id' => current_user.id }])
    request.headers['Authorization'] = "Bearer #{token}"
    allow(controller).to receive(:current_user).and_return(current_user)
  end

  describe 'GET #show' do
    context 'when user is found' do
      it 'returns the user profile' do
        get :show, params: { username: 'otheruser' }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('otheruser')
      end
    end

    context 'when user is not found' do
      it 'returns an error' do
        allow(User).to receive(:find_by_username).with('unknownuser').and_return(nil)

        get :show, params: { username: 'unknownuser' }

        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('User not found')
      end
    end
  end

  describe 'POST #follow' do
    context 'when authenticated' do
      it 'follows the user and returns the profile' do
        allow(User).to receive(:find_by_username).with('otheruser').and_return(other_user)
        allow(current_user).to receive(:follow).with(other_user).and_return(true)

        post :follow, params: { username: 'otheruser' }

        expect(response).to have_http_status(:found)
      end
    end

    context 'when not authenticated' do
      it 'returns an error' do
        request.headers['Authorization'] = nil

        post :follow, params: { username: 'otheruser' }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE #unfollow' do
    context 'when authenticated' do
      it 'unfollows the user and returns the profile' do
        allow(current_user).to receive(:follow).with(other_user).and_return(true)
        allow(current_user).to receive(:unfollow).with(other_user).and_return(true)

        delete :unfollow, params: { username: 'otheruser' }

        expect(response).to have_http_status(:found)
      end
    end

    context 'when not authenticated' do
      it 'returns an error' do
        request.headers['Authorization'] = nil

        delete :unfollow, params: { username: 'otheruser' }, as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors']).to include('Not Authenticated')
      end
    end
  end
end
