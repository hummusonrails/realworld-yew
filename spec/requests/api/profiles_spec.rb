require 'rails_helper'

RSpec.describe "Api::Profiles", type: :request do
  let(:other_user) { User.new(id: 'other-user-id', username: 'otheruser', email: 'otheruser@example.com', password_digest: BCrypt::Password.create('password'), bio: 'Other user bio', image: 'other_image.png') }
  let(:bucket) { instance_double(Couchbase::Bucket) }
  let(:collection) { instance_double(Couchbase::Collection) }
  let(:cluster) { instance_double(Couchbase::Cluster) }
  let(:token) { JWT.encode({ user_id: current_user.id }, Rails.application.secret_key_base) }
  let(:lookup_in_result) { instance_double(Couchbase::Collection::LookupInResult, content: [], exists?: true) }

  before do
    allow(User).to receive(:find_by_username).with('otheruser').and_return(other_user)
  end

  describe "GET /index" do
    pending "add some examples (or delete) #{__FILE__}"
  end
end
