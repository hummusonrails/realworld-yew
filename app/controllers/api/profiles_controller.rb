module Api
  class ProfilesController < ApplicationController
    before_action :authenticate_user, only: %i[follow unfollow]

    def show
      user = User.find_by_username(params[:username])
      if user
        render json: { profile: user.to_hash.except('password_digest') }
      else
        render json: { errors: ['User not found'] }, status: :not_found
      end
    end

    def follow
      user = User.find_by_username(params[:username])
      if @current_user.follow(user)
        render json: { profile: user.to_hash.except('password_digest') }
      else
        render json: { errors: ['Unable to follow user'] }, status: :unprocessable_entity
      end
    end

    def unfollow
      user = User.find_by_username(params[:username])
      if @current_user.unfollow(user)
        render json: { profile: user.to_hash.except('password_digest') }
      else
        render json: { errors: ['Unable to unfollow user'] }, status: :unprocessable_entity
      end
    end
  end
end
