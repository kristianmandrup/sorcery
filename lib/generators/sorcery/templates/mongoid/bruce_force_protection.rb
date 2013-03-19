module Sorcery
  module BruteForceActivation
    extend ActiveSupport::Concern

    include do
      field :failed_logins_count, :type => Integer, :default => 0
      field :lock_expires_at,     :type => DateTime
      field :unlock_token,        :type => String
    end
  end
end
