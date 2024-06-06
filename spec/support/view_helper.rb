# spec/support/view_helper.rb
module ViewHelper
  def stub_image_tag
    allow_any_instance_of(ActionView::Helpers::AssetTagHelper).to receive(:image_tag) do |instance, *args|
      src = args.first
      if src.start_with?("http") || src.include?("default_profile.png")
        instance.send(:original_image_tag, *args)
      else
        instance.send(:original_image_tag, "placeholder_image.png", alt: args.last[:alt])
      end
    end
  end
end

RSpec.configure do |config|
  config.before(:each, type: :controller) do
    ActionView::Helpers::AssetTagHelper.class_eval do
      alias_method :original_image_tag, :image_tag unless method_defined?(:original_image_tag)
    end
  end
end
