class SectionStaff < ApplicationRecord
  include InheritsUniversity

  ROLES = %w[profesor ayudante].freeze

  belongs_to :section
  belongs_to :user
  belongs_to :assigned_by, class_name: "User"

  inherits_university_from :section

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :section_id }
end
