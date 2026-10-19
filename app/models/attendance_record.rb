class AttendanceRecord < ApplicationRecord
  include InheritsUniversity

  belongs_to :attendance_session
  belongs_to :student, class_name: "User"

  inherits_university_from :attendance_session
end
