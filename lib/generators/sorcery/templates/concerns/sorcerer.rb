class <%= full_model_class %>
  module Sorcerer
    extend ActiveSupport::Concern

    included do
      include ::Sorcery::Core
      authenticates_with_sorcery!
    end
  end
end