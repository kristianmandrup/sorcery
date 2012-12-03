class <%= model_class_name %>
  module UserActivation
    extend ActiveSupport::Concern

    included do
      field :activation_state,            :type => String
      field :activation_token,            :type => String
      field :activation_token_expires_at, :type => DateTime
    end
  end
end