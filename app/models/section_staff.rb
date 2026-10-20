class SectionStaff < ApplicationRecord
  include ProfessorAssignment

  belongs_to :section
  belongs_to :user
  belongs_to :assigned_by, class_name: "User"
end
