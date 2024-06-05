class ApplicationController < ActionController::Base
  helper_method :logged_in?, :current_user

  def logged_in?
    !!current_user
  end

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  rescue ActiveRecord::RecordNotFound
    session[:user_id] = nil
    nil
  end

  def authenticate_user
    if request.format.json?
      token = request.headers['Authorization'].split(' ').last
      decoded = JWT.decode(token, Rails.application.secret_key_base).first
      @current_user = User.find(decoded['user_id'])
      render json: { errors: ['Not Authenticated'] }, status: :unauthorized unless @current_user
    else
      redirect_to login_path, alert: 'You must be logged in to access this page.' unless current_user
    end
  rescue
    render json: { errors: ['Not Authenticated'] }, status: :unauthorized if request.format.json?
  end
end
