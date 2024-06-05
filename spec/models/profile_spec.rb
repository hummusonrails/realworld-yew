require 'rails_helper'
require 'couchbase'

RSpec.describe Profile, type: :model do
  let(:profile) { Profile.new(id: 'profile-id', username: 'testuser', bio: 'This is a test bio', image: 'test_image.png', following: false) }

  describe '#to_hash' do
    it 'returns a hash with the correct attributes' do
      expect(profile.to_hash).to eq({
        'username' => 'testuser',
        'bio' => 'This is a test bio',
        'image' => 'test_image.png',
        'following' => false
      })
    end
  end
end
