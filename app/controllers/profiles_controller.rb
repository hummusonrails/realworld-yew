class ProfilesController < ApplicationController
  before_action :authenticate_user, only: [:follow, :unfollow]

  def show
    user = User.find_by_username(params[:username])
    profile = Profile.new(user.to_hash.merge(following: current_user&.following?(user)))
    render json: { profile: profile.to_hash }
  end

  def follow
    user = User.find_by_username(params[:username])
    current_user.follow(user)
    profile = Profile.new(user.to_hash.merge(following: true))
    render json: { profile: profile.to_hash }
  end

  def unfollow
    user = User.find_by_username(params[:username])
    current_user.unfollow(user)
    profile = Profile.new(user.to_hash.merge(following: false))
    render json: { profile: profile.to_hash }
  end
end
