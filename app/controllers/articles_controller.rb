class ArticlesController < ApplicationController
  before_action :authenticate_user, only: [:create, :update, :destroy, :favorite, :unfavorite]

  def index
    articles = Article.all
    render json: { articles: articles.map(&:to_hash), articlesCount: articles.count }
  end

  def show
    article = Article.find_by_slug(params[:slug])
    render json: { article: article.to_hash }
  end

  def create
    article = current_user.articles.new(article_params)
    article.slug = generate_slug(article.title)
    if article.save
      render json: { article: article.to_hash }, status: :created
    else
      render json: { errors: article.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    article = current_user.articles.find_by_slug(params[:slug])
    if article.update(article_params)
      render json: { article: article.to_hash }
    else
      render json: { errors: article.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    article = current_user.articles.find_by_slug(params[:slug])
    article.destroy
    head :no_content
  end

  def feed
    articles = current_user.feed
    render json: { articles: articles.map(&:to_hash), articlesCount: articles.count }
  end

  def favorite
    article = Article.find_by_slug(params[:slug])
    current_user.favorite(article)
    render json: { article: article.to_hash }
  end

  def unfavorite
    article = Article.find_by_slug(params[:slug])
    current_user.unfavorite(article)
    render json: { article: article.to_hash }
  end

  private

  def article_params
    params.require(:article).permit(:title, :description, :body, tagList: [])
  end

  def generate_slug(title)
    title.parameterize
  end
end
