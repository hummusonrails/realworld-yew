# frozen_string_literal: true

class ProfilesController < ApplicationController
  before_action :authenticate_user, only: %i[follow unfollow]

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
    @current_user = current_user

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
      format.html { render :show }
      format.json { render json: { profile: @profile.to_hash, articles: @articles.map(&:to_hash) } }
    end
  end

  def follow
    user = User.find_by_username(params[:username])

    if user.nil?
      respond_to do |format|
        format.html { redirect_to root_path, alert: 'User not found' }
        format.json { render json: { errors: ['User not found'] }, status: :not_found }
      end
      return
    end

    if current_user.following?(user)
      respond_to do |format|
        format.html { redirect_to profile_path(username: user.username), alert: 'User already followed.' }
        format.json { render json: { errors: ['User already followed'] }, status: :unprocessable_entity }
      end
      return
    end

    current_user.follow(user)
    @profile = Profile.new(user.to_hash.merge(following: true))

    respond_to do |format|
      format.html { redirect_to profile_path(username: user.username), notice: 'User followed successfully.' }
      format.json { render json: { profile: @profile.to_hash } }
    end
  end

  def unfollow
    user = User.find_by_username(params[:username])

    if user.nil?
      respond_to do |format|
        format.html { redirect_to root_path, alert: 'User not found' }
        format.json { render json: { errors: ['User not found'] }, status: :not_found }
      end
      return
    end

    unless current_user.following?(user)
      respond_to do |format|
        format.html { redirect_to profile_path(username: user.username), alert: 'User not followed.' }
        format.json { render json: { errors: ['User not followed'] }, status: :unprocessable_entity }
      end
      return
    end

    current_user.unfollow(user)
    @profile = Profile.new(user.to_hash.merge(following: false))

    respond_to do |format|
      format.html { redirect_to profile_path(username: user.username), notice: 'User unfollowed successfully.' }
      format.json { render json: { profile: @profile.to_hash } }
    end
  end
end
