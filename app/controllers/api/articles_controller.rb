module Api
  class ArticlesController < ApplicationController
    before_action :authenticate_user, only: %i[feed create update destroy favorite unfavorite]

    def index
      articles = Article.all

      articles = articles.select { |article| article.tag_list&.include?(params[:tag]) } if params[:tag]

      articles = articles.select { |article| article.author&.username == params[:author] } if params[:author]

      articles = articles.select { |article| article.favorited_by?(params[:favorited]) } if params[:favorited]

      articles = articles.drop(params[:offset].to_i) if params[:offset]
      articles = articles.take(params[:limit].to_i) if params[:limit]

      render json: { articles: articles.map(&:to_hash) }
    end

    def feed
      articles = @current_user.feed
      render json: { articles: articles.map(&:to_hash) }
    end

    def show
      article = Article.find_by_slug(params[:slug])
      if article
        render json: { article: article.to_hash }
      else
        render json: { errors: ['Article not found'] }, status: :not_found
      end
    end

    def create
      article = Article.new(article_params)
      article.author_id = @current_user.id
      if article.save
        render json: { article: article.to_hash }, status: :created
      else
        render json: { errors: article.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      article = @current_user.find_article_by_slug(params[:slug])
      if article.update(article_params)
        render json: { article: article.to_hash }
      else
        render json: { errors: article.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      article = Article.find_by_slug(params[:slug])
      if article && article.author_id == @current_user.id
        article.destroy
        render json: { message: 'Article deleted successfully' }, status: :ok
      else
        render json: { errors: ['You are not authorized to delete this article'] }, status: :forbidden
      end
    end

    def favorite
      article = Article.find_by_slug(params[:slug])
      if @current_user.favorite(article)
        render json: { article: article.to_hash }
      else
        render json: { errors: ['Unable to favorite article'] }, status: :unprocessable_entity
      end
    end

    def unfavorite
      article = Article.find_by_slug(params[:slug])
      if @current_user.unfavorite(article)
        render json: { article: article.to_hash }
      else
        render json: { errors: ['Unable to unfavorite article'] }, status: :unprocessable_entity
      end
    end

    private

    def article_params
      params.require(:article).permit(:title, :description, :body, tag_list: [])
    end
  end
end
