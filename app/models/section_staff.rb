class SectionStaff < ApplicationRecord
  belongs_to :section
  belongs_to :user
  belongs_to :assigned_by, class_name: "User"
end
