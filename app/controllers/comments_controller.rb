class CommentsController < ApplicationController
  before_action :authenticate_user, only: [:create, :destroy]

  def index
    article = Article.find_by_slug(params[:article_id])
    comments = article.comments
    render json: { comments: comments.map(&:to_hash) }
  end

  def create
    article = Article.find_by_slug(params[:article_id])
    comment = Comment.new(comment_params)
    comment.author_id = current_user.id
    article.add_comment(comment)
    if comment.save
      render json: { comment: comment.to_hash }, status: :created
    else
      render json: { errors: comment.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    comment = Comment.find(params[:id])
    comment.destroy
    head :no_content
  end

  private

  def comment_params
    params.require(:comment).permit(:body, :article_id, :id)
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
