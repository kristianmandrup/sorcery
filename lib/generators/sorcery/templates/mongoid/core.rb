class <%= model_class_name %>
  module Core
    extend ActiveSupport::Concern

    included do
      include Mongoid::Timestamps
      # if you use another field as a username, for example email, you can safely remove this field.      
      field :username,         :type => String

      # if you use this field as a username, you might want to make it :null => false.
      field :email,            :type => String
      field :crypted_password, :type => String
      field :salt,             :type => String      
    end
  end
end