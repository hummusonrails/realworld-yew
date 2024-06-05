class ProfilesController < ApplicationController
  before_action :authenticate_user, only: [:follow, :unfollow]

  def show
    user = User.find_by_username(params[:username])
    if user.nil?
      render json: { errors: ['User not found'] }, status: :not_found
      return
    end
    profile = Profile.new(user.to_hash.merge(following: current_user&.following?(user)))
    render json: { profile: profile.to_hash }
  end

  def follow
    user = User.find_by_username(params[:username])
    if user.nil?
      render json: { errors: ['User not found'] }, status: :not_found
      return
    end
    current_user.follow(user)
    profile = Profile.new(user.to_hash.merge(following: true))
    render json: { profile: profile.to_hash }
  end

  def unfollow
    user = User.find_by_username(params[:username])
    if user.nil?
      render json: { errors: ['User not found'] }, status: :not_found
      return
    end
    current_user.unfollow(user)
    profile = Profile.new(user.to_hash.merge(following: false))
    render json: { profile: profile.to_hash }
  end

  private

  def authenticate_user
    token = request.headers['Authorization'].split(' ').last
    decoded = JWT.decode(token, Rails.application.secret_key_base).first
    @current_user = User.find(decoded['user_id'])
  rescue
    render json: { errors: ['Not Authenticated'] }, status: :unauthorized
  end

  def current_user
    @current_user
  end
end
