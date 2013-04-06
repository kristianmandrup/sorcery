class User < ActiveRecord::Base
<<<<<<< HEAD
  attr_accessible :username, :email, :password, :password_confirmation, :authentications_attributes
=======
  attr_accessible :email, :password, :password_confirmation, :authentications_attributes, :username
>>>>>>> ec97aa5aab02d362bc51acac83b9d13fd1880082
  
  has_many :authentications, :dependent => :destroy
  has_many :access_tokens, :dependent => :delete_all
  accepts_nested_attributes_for :authentications
end
