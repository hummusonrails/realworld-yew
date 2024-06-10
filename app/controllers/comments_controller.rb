class CommentsController < ApplicationController
  before_action :authenticate_user, only: %i[create destroy]

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
end
