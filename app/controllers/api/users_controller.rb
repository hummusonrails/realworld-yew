module Api
  class UsersController < ApplicationController
    before_action :authenticate_user, only: %i[update current]

    def login
      user = User.find_by_email(user_params[:email])
      if user && BCrypt::Password.new(user.password_digest) == user_params[:password]
        render json: { user: user.to_hash.except('password_digest').merge(token: encode_token(user_id: user.id)) }
      else
        render json: { errors: ['Invalid email or password'] }, status: :unauthorized
      end
    end

    def register
      user = User.new(user_params)
      if user.save
        render json: { user: user.to_hash.except('password_digest').merge(token: encode_token(user_id: user.id)) },
               status: :created
      else
        render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def current
      user = User.find_by_email(user_params[:email])
      if user
        render json: { user: user.to_hash.except('password_digest') }
      else
        render json: { errors: ['User not found'] }, status: :not_found
      end
    end

    def update
      user = User.find_by_email(user_params[:email])
      if user
        user.update(user_params)
        render json: { user: user.to_hash.except('password_digest') }
      else
        render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def user_params
      params.require(:user).permit(:email, :username, :password, :bio, :image)
    end

    def encode_token(payload)
      JWT.encode(payload, Rails.application.secret_key_base)
    end
  end
end
