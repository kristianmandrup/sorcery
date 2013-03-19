module Sorcery
  module RememberMe
    extend ActiveSupport::Concern

    included do
      field :remember_me_token,            :type => String
      field :remember_me_token_expires_at, :type => DateTime
    end
  end
end