class CourseCoordinator < ApplicationRecord
  belongs_to :course
  belongs_to :term
  belongs_to :user
  belongs_to :assigned_by, class_name: "User"
end
