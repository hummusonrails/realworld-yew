class ArticlesController < ApplicationController
  before_action :authenticate_user, only: [:create, :update, :destroy, :favorite, :unfavorite, :feed]

  def index
    @articles = Article.all || []
    @tags = Tag.all || []

    render :index
  end

  def show
    @article = Article.find_by_slug(params[:id])
    @is_favorited = current_user.favorited?(@article) if current_user

    if @article
      @comment = Comment.new

      respond_to do |format|
        format.html { render :show }
        format.json { render json: { article: @article.to_hash } }
      end
    else
      respond_to do |format|
        format.html { redirect_to root_path, alert: 'Article not found' }
        format.json { render json: { errors: ['Article not found'] }, status: :not_found }
      end
    end
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

    if article.nil?
      respond_to do |format|
        format.html { redirect_to root_path, alert: 'Article not found' }
        format.json { render json: { errors: ['Article not found'] }, status: :not_found }
      end
      return
    end

    if current_user.favorited?(article)
      respond_to do |format|
        format.html { redirect_to article_path(article.slug), alert: 'Article already favorited.' }
        format.json { render json: { errors: ['Article already favorited'] }, status: :unprocessable_entity }
      end
      return
    end

    current_user.favorite(article)

    respond_to do |format|
      format.html { redirect_to article_path(article.slug), notice: 'Article favorited successfully.' }
      format.json { render json: { article: article.to_hash } }
    end
  end

  def unfavorite
    article = Article.find_by_slug(params[:id])

    if article.nil?
      respond_to do |format|
        format.html { redirect_to root_path, alert: 'Article not found' }
        format.json { render json: { errors: ['Article not found'] }, status: :not_found }
      end
      return
    end

    unless current_user.favorited?(article)
      respond_to do |format|
        format.html { redirect_to article_path(article.slug), alert: 'Article not favorited.' }
        format.json { render json: { errors: ['Article not favorited'] }, status: :unprocessable_entity }
      end
      return
    end

    current_user.unfavorite(article)

    respond_to do |format|
      format.html { redirect_to article_path(article.slug), notice: 'Article unfavorited successfully.' }
      format.json { render json: { article: article.to_hash } }
    end
  end

  private

  def article_params
    params.require(:article).permit(:title, :description, :body, tag_list: [])
  end
end
