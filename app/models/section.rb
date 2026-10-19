class Section < ApplicationRecord
  belongs_to :university
  belongs_to :course
  belongs_to :term
  has_many :section_staffs, dependent: :destroy
  has_many :enrollments, dependent: :destroy
  has_many :evaluations, dependent: :restrict_with_error
  has_many :attendance_sessions, dependent: :restrict_with_error
  has_many :announcements, dependent: :destroy
end
