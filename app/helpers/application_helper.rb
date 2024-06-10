# frozen_string_literal: true

module ApplicationHelper
  def markdown(text)
    return '' if text.nil? || text.empty?

    renderer = Redcarpet::Render::HTML.new(filter_html: true, hard_wrap: true)
    markdown = Redcarpet::Markdown.new(renderer, {})
    markdown.render(text).html_safe
  end
end
