class Term < ApplicationRecord
  acts_as_tenant :university
  has_many :sections, dependent: :destroy
  has_many :course_coordinators, dependent: :destroy
end
