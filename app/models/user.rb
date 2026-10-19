class User < ApplicationRecord
  # Accounts are created by staff (no :registerable). Password recovery (A2) is not enabled yet.
  devise :database_authenticatable, :rememberable, :validatable, :lockable

  # The role lives in users.role, as in the C4 code level (user_roles is not used for authorization).
  enum :role, {
    director: "director",
    administrativo: "administrativo",
    profesor: "profesor",
    ayudante: "ayudante",
    alumno: "alumno"
  }, validate: true

  # Users are looked up by Devise before a tenant exists, so User is not tenant-scoped.
  # The director manages both universities and has no university of its own.
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

  validates :first_name, :last_name, :rut, presence: true
  validates :rut, uniqueness: { scope: :university_id }
  validates :university, presence: true, unless: :director?
  validates :university, absence: true, if: :director?

  def name
    [ first_name, last_name ].compact_blank.join(" ")
  end

  def role_name
    I18n.t("roles.#{role}")
  end
end
