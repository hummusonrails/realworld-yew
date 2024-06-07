module ApplicationHelper
  def markdown(text)
    if text.nil? || text.empty?
      return ''
    end

    renderer = Redcarpet::Render::HTML.new(filter_html: true, hard_wrap: true)
    markdown = Redcarpet::Markdown.new(renderer, extensions = {})
    markdown.render(text).html_safe
  end
end
