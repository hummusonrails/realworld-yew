# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#markdown' do
    let(:markdown_text) { "# Header\n\nThis is **bold** text and this is *italic* text." }
    let(:html_output) do
      "<h1>Header</h1>\n\n<p>This is <strong>bold</strong> text and this is <em>italic</em> text.</p>\n"
    end

    it 'converts markdown to HTML' do
      expect(helper.markdown(markdown_text)).to eq(html_output)
    end

    it 'handles empty strings' do
      expect(helper.markdown('')).to eq('')
    end

    it 'handles nil input' do
      expect(helper.markdown(nil)).to eq('')
    end
  end
end
