class AttendanceSession < ApplicationRecord
  belongs_to :section
  belongs_to :recorded_by, class_name: "User"
  has_many :attendance_records, dependent: :destroy
end
