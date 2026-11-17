class AnnouncementPolicy
  include CanCan::Ability

  def initialize(user)
    # B12: profesores, and student accounts that are ayudantes of some section. An alumno account can be one
    # (Trello A23).
    if user.profesor? || (user.student_account? && SectionStaff.exists?(user_id: user.id, university_id: user.university_id))
      can :index, :announcements
      can :read, Announcement do |announcement|
        course = Course.find_by(id: announcement.course_id)
        course && (
          SectionStaff.joins(:section).exists?(user_id: user.id, sections: { course_id: course.id }) ||
          CourseCoordinator.exists?(course_id: course.id, user_id: user.id)
        )
      end
    end

    # B16: a student reads announcements only while actively enrolled among their recipients.
    if user.student_account? && user.university_id.present?
      can :index, :announcements if Enrollment.exists?(student_id: user.id, active: true, university_id: user.university_id)
      can :read, Announcement do |announcement|
        Announcement.readable_by(user).exists?(id: announcement.id)
      end
    end

    return unless user.profesor?

    can :create, Announcement do |announcement|
      course = announcement.course
      next false unless course && course.university_id == user.university_id

      coordinator = CourseCoordinator.exists?(course_id: course.id, user_id: user.id)
      teaching = SectionStaff.joins(:section).exists?(user_id: user.id, role: "profesor", sections: { course_id: course.id })
      next false unless coordinator || teaching

      section = announcement.section
      section.nil? || (section.course_id == course.id &&
        (coordinator || SectionStaff.exists?(section_id: section.id, user_id: user.id, role: "profesor")))
    end
  end
end
