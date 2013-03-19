module Sorcery
  module Core
    extend ActiveSupport::Concern

    included do
      field :last_login_at,     :type => DateTime
      field :last_logout_at,    :type => DateTime
      field :last_activity_at,  :type => DateTime
    end
  end
end