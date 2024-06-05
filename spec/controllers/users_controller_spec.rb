require 'rails_helper'
require 'couchbase'
require 'jwt'

RSpec.describe UsersController, type: :controller do
  let(:user) { User.new(id: 'user-id', username: 'testuser', email: 'test@example.com', password_digest: BCrypt::Password.create('password'), bio: 'Test bio', image: 'test_image.png') }
  let(:token) { JWT.encode({ user_id: user.id }, Rails.application.secret_key_base) }

  before do
    allow(User).to receive(:new).and_return(user)
    allow(User).to receive(:find_by_email).and_return(user)
    allow(User).to receive(:find).with(user.id).and_return(user)
    allow(JWT).to receive(:decode).and_return([{ 'user_id' => user.id }])
    request.headers['Authorization'] = "Bearer #{token}"
  end

  describe 'POST #create' do
    context 'with valid parameters' do
      it 'creates a new user and returns the user with a token' do
        allow(user).to receive(:save).and_return(true)

        post :create, params: { user: { username: 'testuser', email: 'test@example.com', password: 'password', bio: 'Test bio', image: 'test_image.png' } }

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)['user']['username']).to eq('testuser')
        expect(JSON.parse(response.body)['user']).to have_key('token')
      end
    end

    context 'with invalid parameters' do
      it 'returns an error' do
        allow(user).to receive(:save).and_return(false)
        allow(user).to receive_message_chain(:errors, :full_messages).and_return(['Error message'])

        post :create, params: { user: { username: 'testuser', email: 'test@example.com', password: 'password', bio: 'Test bio', image: 'test_image.png' } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to include('Error message')
      end
    end
  end

  describe 'POST #login' do
    context 'with valid credentials' do
      it 'returns the user with a token' do
        allow(BCrypt::Password).to receive(:new).and_return(BCrypt::Password.create('password'))

        post :login, params: { user: { email: 'test@example.com', password: 'password' } }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['user']['username']).to eq('testuser')
        expect(JSON.parse(response.body)['user']).to have_key('token')
      end
    end

    context 'with invalid credentials' do
      it 'returns an error' do
        allow(BCrypt::Password).to receive(:new).and_return(BCrypt::Password.create('wrong_password'))

        post :login, params: { user: { email: 'test@example.com', password: 'password' } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to include('Invalid email or password')
      end
    end
  end

  describe 'GET #show' do
    context 'when authenticated' do
      it 'returns the current user' do
        get :show

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['user']['username']).to eq('testuser')
      end
    end

    context 'when not authenticated' do
      it 'returns an error' do
        request.headers['Authorization'] = nil

        get :show

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors']).to include('Not Authenticated')
      end
    end
  end

  describe 'PUT #update' do
    context 'when authenticated' do
      it 'updates the current user and returns the updated user' do
        updated_attributes = { username: 'updateduser', bio: 'Updated bio' }
        allow(user).to receive(:update).and_wrap_original do |m, *args|
          m.call(updated_attributes)
        end

        put :update, params: { user: updated_attributes }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['user']['username']).to eq('updateduser')
      end
    end

    context 'when not authenticated' do
      it 'returns an error' do
        request.headers['Authorization'] = nil

        put :update, params: { user: { username: 'updateduser', bio: 'Updated bio' } }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors']).to include('Not Authenticated')
      end
    end
  end
end
