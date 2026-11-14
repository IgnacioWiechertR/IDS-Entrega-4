class Section < ApplicationRecord
  acts_as_tenant :university
  belongs_to :course
  belongs_to :term

  has_many :section_staffs, dependent: :restrict_with_error
  has_many :enrollments, dependent: :restrict_with_error
  has_many :evaluations, dependent: :restrict_with_error
  has_many :attendance_sessions, dependent: :restrict_with_error
  has_many :announcements, dependent: :restrict_with_error

  validates :number, numericality: { only_integer: true, greater_than: 0 }
  validates :number, uniqueness: { scope: %i[course_id term_id] }
  validate :course_and_term_in_same_university

  # Students with an active enrollment, by last name: the ones on the attendance list.
  def active_students
    User.joins(:enrollments).where(enrollments: { section_id: id, active: true }).order(:last_name, :first_name)
  end

  # Student accounts (an ayudante can study other courses, Trello A23) of the university, without an active
  # enrollment or a teaching role in any section of this course in this term: the ones that can still be
  # enrolled (A24) or assigned as ayudantes (A23).
  def student_accounts_without_role_in_course
    same_course = Section.where(course_id: course_id, term_id: term_id)
    enrolled = Enrollment.where(section: same_course, active: true).select(:student_id)
    staff = SectionStaff.where(section: same_course).select(:user_id)

    User.where(role: %w[alumno ayudante], university_id: university_id)
      .where.not(id: enrolled).where.not(id: staff)
      .order(:last_name, :first_name)
  end

  private

  def course_and_term_in_same_university
    errors.add(:course, :must_match_university) unless same_university?(course_id, course)
    errors.add(:term, :must_match_university) unless same_university?(term_id, term)
  end

  # Inside the active university (A3) a course or term of another university is not visible, so an id
  # without a visible record also counts as a mismatch.
  def same_university?(id, record)
    record ? record.university_id == university_id : id.nil?
  end
end
