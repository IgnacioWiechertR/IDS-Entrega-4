class User < ApplicationRecord
  belongs_to :university, optional: true

  has_many :user_roles, dependent: :destroy
  has_many :course_coordinators, dependent: :destroy
  has_many :assigned_course_coordinators, class_name: "CourseCoordinator", foreign_key: :assigned_by_id, dependent: :destroy
  has_many :section_staffs, dependent: :destroy
  has_many :assigned_section_staffs, class_name: "SectionStaff", foreign_key: :assigned_by_id, dependent: :destroy
  has_many :enrollments, foreign_key: :student_id, dependent: :destroy
  has_many :grades, foreign_key: :student_id, dependent: :destroy
  has_many :entered_grades, class_name: "Grade", foreign_key: :entered_by_id, dependent: :destroy
  has_many :reviewed_grades, class_name: "Grade", foreign_key: :reviewed_by_id, dependent: :nullify
  has_many :recorded_attendance_sessions, class_name: "AttendanceSession", foreign_key: :recorded_by_id, dependent: :destroy
  has_many :attendance_records, foreign_key: :student_id, dependent: :destroy
  has_many :announcements, foreign_key: :author_id, dependent: :destroy
  has_many :notifications, foreign_key: :recipient_id, dependent: :destroy
end
