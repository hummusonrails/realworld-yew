class Api::ApplicationController < ActionController::Base
  skip_before_action :verify_authenticity_token
  helper_method :authenticate_user

  def authenticate_user
    token = request.headers['Authorization'].split(' ').last
    decoded = JWT.decode(token, Rails.application.secret_key_base).first
    @current_user = User.find(decoded['user_id'])
    render json: { errors: ['Not Authenticated'] }, status: :unauthorized unless @current_user
    @current_user
  end
end
