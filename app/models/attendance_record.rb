class AttendanceRecord < ApplicationRecord
  include InheritsUniversity

  enum :status, { presente: "presente", ausente: "ausente" }, validate: true

  belongs_to :attendance_session
  belongs_to :student, class_name: "User"

  inherits_university_from :attendance_session

  validates :student_id, uniqueness: { scope: :attendance_session_id }
end
