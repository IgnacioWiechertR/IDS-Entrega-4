class User < ApplicationRecord
  # Accounts are created by staff (no :registerable). Password recovery (A2) is not enabled yet.
  devise :database_authenticatable, :rememberable, :validatable, :lockable

  # One role per account. The role in each course lives in section_staffs (profesor/ayudante) and enrollments (alumno).
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

  normalizes :rut, with: ->(rut) { Rut.normalize(rut) }

  validates :first_name, :last_name, :rut, presence: true
  validate :rut_has_valid_check_digit, :rut_not_taken_in_university, if: -> { rut.present? }
  validates :university, presence: true, unless: :director?
  validates :university, absence: true, if: :director?

  def name
    [ first_name, last_name ].compact_blank.join(" ")
  end

  def role_name
    I18n.t("roles.#{role}")
  end

  # An ayudante is also a student: it can be enrolled in other courses (Trello A23).
  def student_account?
    alumno? || ayudante?
  end

  private

  def rut_has_valid_check_digit
    errors.add(:rut, :invalid_rut) unless Rut.valid?(rut)
  end

  # A RUT is unique per university: the same person can have an account in each one (A8). The error names the
  # existing account so the administrativo can find it instead of creating a second one.
  def rut_not_taken_in_university
    existing = User.where(university_id: university_id, rut: rut).where.not(id: id).first
    errors.add(:rut, :taken_by_account, account: "#{existing.name} (#{existing.email})") if existing
  end
end
