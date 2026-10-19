class Term < ApplicationRecord
  belongs_to :university
  has_many :sections, dependent: :destroy
  has_many :course_coordinators, dependent: :destroy
end
