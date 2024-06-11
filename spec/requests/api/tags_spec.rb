# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Tags', type: :request do
  let(:headers) { { 'Content-Type': 'application/json' } }
  let(:tag1) { Tag.new(id: 'tag1-id', name: 'tag1', type: 'tag') }
  let(:tag2) { Tag.new(id: 'tag2-id', name: 'tag2', type: 'tag') }

  before do
    mock_couchbase_methods

    allow(Tag).to receive(:all).and_return([tag1, tag2])
  end

  describe 'GET /api/tags' do
    it 'returns all tags' do
      get '/api/tags', headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['tags']).to eq(['tag1', 'tag2'])
    end
  end
end
