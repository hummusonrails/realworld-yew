require 'rails_helper'
require 'couchbase'

RSpec.describe Profile, type: :model do
  let(:profile) do
    Profile.new(id: 'profile-id', username: 'testuser', email: 'test@example.com', password_digest: 'password',
                bio: 'This is a test bio', image: 'test_image.png', following: [], favorites: [])
  end

  describe '#to_hash' do
    it 'returns a hash with the correct attributes' do
      expect(profile.to_hash).to eq({
                                      'username' => 'testuser',
                                      'email' => 'test@example.com',
                                      'password_digest' => 'password',
                                      'bio' => 'This is a test bio',
                                      'image' => 'test_image.png',
                                      'following' => [],
                                      'favorites' => []
                                    })
    end
  end
end
