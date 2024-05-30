class Profile
  include ActiveModel::Model
  attr_accessor :id, :username, :bio, :image, :following

  def to_hash
    {
      'username' => username,
      'bio' => bio,
      'image' => image,
      'following' => following
    }
  end
end
