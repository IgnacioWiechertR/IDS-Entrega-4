class SyllabusPolicy
  include CanCan::Ability

  # Reading follows the course (whoever can read the course reads its syllabus), so it is checked against Course.
  # Uploading or replacing it (:upload) is for the administrativo of the university (Entrega 3, "asigna syllabus")
  # and the coordinator of the course in that term (the profesor in charge of it, Entrega 2).
  def initialize(user)
    return unless user.university_id.present?

    can :upload, Syllabus, university_id: user.university_id if user.administrativo?

    if user.profesor?
      can :upload, Syllabus do |syllabus|
        syllabus.course&.university_id == user.university_id &&
          CourseCoordinator.exists?(course_id: syllabus.course_id, term_id: syllabus.term_id, user_id: user.id)
      end
    end

    # Nobody replaces it once its term began (Syllabus#locked?).
    cannot :upload, Syllabus, &:locked?
  end
end
