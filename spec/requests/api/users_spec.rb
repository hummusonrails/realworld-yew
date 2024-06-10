# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Users API', type: :request do
  let(:headers) { { 'Content-Type': 'application/json' } }
  let(:current_user) do
    User.new(id: 'current-user-id', username: 'currentuser', email: 'currentuser@example.com',
             password_digest: BCrypt::Password.create('password'), bio: 'Current user bio', image: 'current_image.png')
  end
  let(:new_user) do
    User.new(id: 'new-user-id', username: 'newuser', email: 'newuser@example.com',
             password_digest: BCrypt::Password.create('password'), bio: 'New user bio', image: 'new_image.png')
  end
  let(:token) { JWT.encode({ user_id: current_user.id }, Rails.application.secret_key_base) }

  before do
    mock_couchbase_methods

    allow(User).to receive(:new).and_call_original
    allow(User).to receive(:find_by_email).and_return(current_user)
    allow(User).to receive(:find).with(current_user.id).and_return(current_user)
    allow(User).to receive(:find_by_username).with(current_user.username).and_return(current_user)
    allow(User).to receive(:find_by_username).with(new_user.username).and_return(new_user)
    allow(JWT).to receive(:decode).and_return([{ 'user_id' => current_user.id }])
  end

  describe 'POST /api/users/login' do
    let(:valid_credentials) { { user: { email: current_user.email, password: 'password' } }.to_json }
    let(:invalid_credentials) { { user: { email: current_user.email, password: 'wrongpassword' } }.to_json }

    it 'authenticates the user and returns a token' do
      headers = {
        'Content-Type': 'application/json',
        'Authorization': "Bearer #{token}"
      }
      post('/api/users/login', params: valid_credentials, headers:)
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['user']['email']).to eq(current_user.email)
    end

    it 'returns an error for invalid credentials' do
      post('/api/users/login', params: invalid_credentials, headers:)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/users' do
    it 'creates a new user' do
      allow(User).to receive(:new).and_return(new_user)
      allow(new_user).to receive(:save).and_return(true)

      post '/api/users',
           params: { user: { username: 'newuser', email: 'newuser@example.com', password: 'password' } }.to_json, headers: { 'Content-Type': 'application/json' }

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['user']['email']).to eq('newuser@example.com')
    end
  end

  describe 'GET /api/user' do
    it 'returns the current user' do
      allow(User).to receive(:find_by_email).with(current_user.email).and_return(current_user)

      headers = {
        'Content-Type': 'application/json',
        'Authorization': "Bearer #{token}"
      }
      get('/api/user', params: { user: { email: 'currentuser@example.com' } }, headers:)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['user']['email']).to eq(current_user.email)
    end
  end

  describe 'PUT /api/user' do
    let(:valid_attributes) { { user: { email: 'updated@example.com', bio: 'New bio' } }.to_json }

    it 'updates the current user' do
      allow(mock_collection).to receive(:upsert).with(current_user.id, hash_including(
                                                                         'email' => 'updated@example.com',
                                                                         'bio' => 'New bio',
                                                                         'favorites' => [],
                                                                         'following' => [],
                                                                         'image' => 'current_image.png',
                                                                         'password_digest' => current_user.password_digest,
                                                                         'type' => 'user',
                                                                         'username' => 'currentuser'
                                                                       ))

      put '/api/user', params: valid_attributes, headers: headers.merge('Authorization' => "Token #{token}")
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['user']['email']).to eq('updated@example.com')
    end
  end

  describe 'GET /api/profiles/:username' do
    let(:other_user) { new_user }

    it 'returns the user profile' do
      get("/api/profiles/#{new_user.username}", headers:)
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['profile']['username']).to eq(new_user.username)
    end
  end

  describe 'POST /api/profiles/:username/follow' do
    let(:other_user) { new_user }

    it 'follows the user' do
      allow(User).to receive(:find_by_username).with(other_user.username).and_return(other_user)
      allow(current_user).to receive(:follow).with(other_user).and_return(true)

      post "/api/profiles/#{other_user.username}/follow",
           headers: {
             'Content-Type': 'application/json',
             'Authorization': "Bearer #{token}"
           }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['profile']['username']).to eq(other_user.username)
    end
  end

  describe 'DELETE /api/profiles/:username/follow' do
    let(:other_user) { new_user }

    it 'unfollows the user' do
      allow(User).to receive(:find_by_username).with(other_user.username).and_return(other_user)
      allow(current_user).to receive(:unfollow).with(other_user).and_return(true)

      delete "/api/profiles/#{other_user.username}/follow",
             headers: {
               'Content-Type': 'application/json',
               'Authorization': "Bearer #{token}"
             }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['profile']['username']).to eq(other_user.username)
    end
  end
end
