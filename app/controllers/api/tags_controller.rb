module Api
  class TagsController < ApplicationController
    skip_before_action :authenticate_user, only: [:index]
    skip_before_action :verify_authenticity_token, if: -> { request.format.json? }

    def index
      @tags = Tag.all
      render json: { tags: @tags.map(&:name) }
    end
  end
end
