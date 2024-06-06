class ArticlesController < ApplicationController
  before_action :authenticate_user, only: [:create, :update, :destroy, :favorite, :unfavorite, :feed]

  def index
    @articles = Article.all || []
    @tags = Tag.all || []

    render :index
  end

  def show
    article = Article.find_by_slug(params[:id])
    render json: { article: article.to_hash }
  end

  def new
    @article = Article.new
  end

  def create
    @article = Article.new(article_params)
    @article.author_id = current_user.id
    @article.slug = @article.generate_slug(@article.title)
    @article.created_at ||= Time.now
    @article.updated_at ||= Time.now
    if @article.save
      redirect_to article_path(@article.slug), notice: 'Article created successfully.'
    else
      flash.now[:alert] = "There were errors saving your article."
      render :new
    end
  end

  def update
    article = current_user.find_article_by_slug(params[:id])
    if article.update(article_params)
      render json: { article: article.to_hash }
    else
      render json: { errors: article.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    article = Article.find_by_slug(params[:id])
    if article && article.author_id == current_user.id
      article.destroy
    else
      render json: { errors: ['Article not found'] }, status: :not_found
      return
    end
    head :no_content
  end

  def feed
    articles = current_user.feed
    render json: { articles: articles.map(&:to_hash), articlesCount: articles.count }
  end

  def favorite
    article = Article.find_by_slug(params[:id])
    current_user.favorite(article)
    render json: { article: article.to_hash }
  end

  def unfavorite
    article = Article.find_by_slug(params[:id])
    current_user.unfavorite(article)
    render json: { article: article.to_hash }
  end

  private

  def article_params
    params.require(:article).permit(:title, :description, :body, tag_list: [])
  end
end
