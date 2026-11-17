class Faculty < ApplicationRecord
  acts_as_tenant :university
  # Deleting a faculty never takes its courses with it.
  has_many :courses, dependent: :restrict_with_error

  normalizes :name, with: ->(name) { name.squish }

  validates :name, presence: true, uniqueness: { scope: :university_id, case_sensitive: false }
end
