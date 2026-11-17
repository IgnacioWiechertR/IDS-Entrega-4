class Announcement < ApplicationRecord
  include InheritsUniversity

  belongs_to :course
  belongs_to :section, optional: true
  belongs_to :author, class_name: "User"
  has_many :notifications, dependent: :destroy

  # B11: the announcement belongs to the university of its course, and so does its author.
  inherits_university_from :course
  accounts_in_university :author

  validates :subject, :body, presence: true
  validate :section_belongs_to_course

  # B16: staff keep B12's course access; enrolled students see general announcements and their own section.
  def self.readable_by(user)
    return none unless user&.university_id.present? && (user.profesor? || user.student_account?)

    announcements = where(university_id: user.university_id)
    staff_courses = SectionStaff.joins(:section).where(user_id: user.id, university_id: user.university_id).select("sections.course_id")
    coordinated_courses = CourseCoordinator.where(user_id: user.id, university_id: user.university_id).select(:course_id)
    readable = announcements.where(course_id: staff_courses).or(announcements.where(course_id: coordinated_courses))
    return readable unless user.student_account?

    enrolled_sections = Enrollment.where(student_id: user.id, active: true, university_id: user.university_id).select(:section_id)
    enrolled_courses = Section.where(id: enrolled_sections).select(:course_id)

    readable.or(announcements.where(section_id: nil, course_id: enrolled_courses))
      .or(announcements.where(section_id: enrolled_sections))
  end

  # B15: only active students of the selected section, or of every section of a general announcement.
  def student_recipients
    sections = course.sections
    sections = sections.where(id: section_id) if section_id.present?
    enrollments = Enrollment.where(section_id: sections.select(:id), active: true)

    User.where(id: enrollments.select(:student_id), university_id: university_id, role: %w[alumno ayudante])
  end

  private

  def section_belongs_to_course
    return unless section && course

    errors.add(:section, :must_match_course) unless section.course_id == course.id
  end
end
