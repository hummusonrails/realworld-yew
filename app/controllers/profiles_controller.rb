class ProfilesController < ApplicationController
  before_action :authenticate_user, only: [:follow, :unfollow]

  def show
    user = User.find_by_username(params[:username])
    if user.nil?
      respond_to do |format|
        format.html { redirect_to root_path, alert: 'User not found' }
        format.json { render json: { errors: ['User not found'] }, status: :not_found }
      end
      return
    end

    @profile = Profile.new(user.to_hash.merge(following: current_user&.following?(user)))
    @articles = user.articles

    respond_to do |format|
      format.html
      format.json { render json: { profile: @profile.to_hash } }
    end
  end

  def favorited
    user = User.find_by_username(params[:username])
    if user.nil?
      respond_to do |format|
        format.html { redirect_to root_path, alert: 'User not found' }
        format.json { render json: { errors: ['User not found'] }, status: :not_found }
      end
      return
    end

    @profile = Profile.new(user.to_hash.merge(following: current_user&.following?(user)))
    @articles = user.favorited_articles

    respond_to do |format|
      format.html
      format.json { render json: { profile: @profile.to_hash, articles: @articles.map(&:to_hash) } }
    end
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
end
