# frozen_string_literal: true

module Api
  class ApplicationController < ActionController::Base
    skip_before_action :verify_authenticity_token
    helper_method :authenticate_user

    def authenticate_user
      unless request.headers['Authorization']
        render json: { errors: ['Not Authenticated'] }, status: :unauthorized
        return
      end

      token = request.headers['Authorization'].split(' ').last
      begin
        decoded = JWT.decode(token, Rails.application.secret_key_base).first
      rescue JWT::DecodeError
        render json: { errors: ['Invalid token'] }, status: :unauthorized
        return
      end
      @current_user = User.find(decoded['user_id'])
      render json: { errors: ['Not Authenticated'] }, status: :unauthorized unless @current_user
      @current_user
    end
  end
end
