class CourseCoordinator < ApplicationRecord
  include InheritsUniversity

  belongs_to :course
  belongs_to :term
  belongs_to :user
  belongs_to :assigned_by, class_name: "User"

  inherits_university_from :course

  validates :course_id, uniqueness: { scope: :term_id }
end
