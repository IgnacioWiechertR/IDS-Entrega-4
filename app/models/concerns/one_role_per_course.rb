# A person has a single role in a course per term: profesor or ayudante of one section, or a student
# enrolled in one section. Coordinating the course (CourseCoordinator) does not count, and inactive
# enrollments neither, so a student can move to another section. The rule lives only here in case
# teaching two sections of the same course is allowed later.
module OneRolePerCourse
  extend ActiveSupport::Concern

  class_methods do
    def one_role_per_course(participant, **options)
      validate(**options) { validate_one_role_per_course(participant) }
    end
  end

  private

  def validate_one_role_per_course(participant)
    person = public_send(participant)
    return unless section && person

    same_course = Section.where(course_id: section.course_id, term_id: section.term_id)
    roles = [
      SectionStaff.where(section: same_course, user: person),
      Enrollment.where(section: same_course, student: person, active: true)
    ].map { |scope| scope.klass == self.class ? scope.where.not(id: id) : scope }

    errors.add(participant, :one_role_per_course) if roles.any?(&:exists?)
  end
end
