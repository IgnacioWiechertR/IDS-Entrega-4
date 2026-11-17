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
  validate :role_compatible_with_assignments, on: :update, if: :will_save_change_to_role?

  # D7: how many accounts of each role a university has, with every role listed (0 when there is none). The
  # director has no university, so it is never counted.
  def self.count_by_role(university)
    counts = where(university: university).group(:role).count
    (roles.keys - [ "director" ]).index_with { |role| counts.fetch(role, 0) }
  end

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

  def role_compatible_with_assignments
    incompatible = []

    if role != "profesor"
      incompatible << "profesor de sección" if SectionStaff.exists?(user_id: id, role: "profesor")
      incompatible << "coordinador de curso" if CourseCoordinator.exists?(user_id: id)
    end

    if role != "ayudante"
      incompatible << "ayudante de sección" if SectionStaff.exists?(user_id: id, role: "ayudante")
    end

    if role != "alumno"
      incompatible << "alumno inscrito en secciones activas" if Enrollment.exists?(student_id: id, active: true)
    end

    return if incompatible.empty?

    errors.add(
      :base,
      "No se puede cambiar el rol a #{role_name} porque la cuenta tiene asignaciones activas como #{incompatible.to_sentence}. " \
      "Desvincúlala primero de sus secciones o cursos."
    )
  end
end
