class Authentication
  include Mongoid::Document
  include Mongoid::Timestamps

  embedded_in :<%= model_class_name.underscore %>, class_name: <%= model_class_name.to_s.inspect %>

  field :provider
  field :uid

  validates :provider,  :presence => true
  validates :uid,       :presence => true
end

