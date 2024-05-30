class UsersController < ApplicationController
  before_action :authenticate_user, only: [:update, :show]

  def create
    user = User.new(user_params)
    user.password_digest = BCrypt::Password.create(params[:user][:password])
    if user.save
      render json: { user: user.to_hash.merge(token: generate_token(user)) }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def login
    user = User.find_by_email(params[:user][:email])
    if user && BCrypt::Password.new(user.password_digest) == params[:user][:password]
      render json: { user: user.to_hash.merge(token: generate_token(user)) }, status: :ok
    else
      render json: { errors: ['Invalid email or password'] }, status: :unprocessable_entity
    end
  end

  def show
    render json: { user: current_user.to_hash }
  end

  def update
    current_user.update(user_params)
    render json: { user: current_user.to_hash }
  end

  private

  def user_params
    params.require(:user).permit(:username, :email, :password, :bio, :image)
  end

  def generate_token(user)
    JWT.encode({ user_id: user.id }, Rails.application.secret_key_base)
  end

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
