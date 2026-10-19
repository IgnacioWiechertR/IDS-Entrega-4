class AttendanceSession < ApplicationRecord
  include InheritsUniversity

  belongs_to :section
  belongs_to :recorded_by, class_name: "User"
  has_many :attendance_records, dependent: :destroy

  inherits_university_from :section

  validates :held_on, presence: true, uniqueness: { scope: :section_id }
end
