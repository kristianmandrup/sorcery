class <%= model_class_name %>
  module ResetPassword
    extend ActiveSupport::Concern

    included do
      field :reset_password_token,            :type => String
      field :reset_password_token_expires_at, :type => DateTime
      field :reset_password_email_sent_at,    :type => DateTime
    end
  end
end