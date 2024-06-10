module Api
  class TagsController < ApplicationController
    def index
      @tags = Tag.all
      render json: { tags: @tags.map(&:name) }
    end
  end
end
