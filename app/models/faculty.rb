class Faculty < ApplicationRecord
  acts_as_tenant :university
  has_many :courses, dependent: :destroy
end
