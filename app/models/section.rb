class Section < ApplicationRecord
  acts_as_tenant :university
  belongs_to :course
  belongs_to :term
  has_many :section_staffs, dependent: :destroy
  has_many :enrollments, dependent: :destroy
  has_many :evaluations, dependent: :destroy
  has_many :attendance_sessions, dependent: :destroy
  has_many :announcements, dependent: :destroy
end
