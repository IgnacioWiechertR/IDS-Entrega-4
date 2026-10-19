class SectionStaff < ApplicationRecord
  include InheritsUniversity

  belongs_to :section
  belongs_to :user
  belongs_to :assigned_by, class_name: "User"

  inherits_university_from :section
end
