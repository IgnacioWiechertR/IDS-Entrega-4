class Course < ApplicationRecord
  acts_as_tenant :university
  belongs_to :faculty
  has_many :sections, dependent: :destroy
  has_many :course_coordinators, dependent: :destroy
  has_many :materials, dependent: :destroy
  has_many :announcements, dependent: :destroy
end
