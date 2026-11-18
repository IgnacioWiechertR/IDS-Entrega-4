class AnnouncementPolicy
  include CanCan::Ability

  def initialize(user)
    # The director reads every announcement of the active university (Announcement is scoped to it, A3) and
    # publishes, edits or deletes none.
    if user.director?
      can :index, :announcements
      can :read, Announcement
    end

    # B12: course staff can read; B16: enrolled students see their course and own-section announcements.
    staff = user.profesor? || (user.student_account? && SectionStaff.exists?(user_id: user.id, university_id: user.university_id))
    enrolled_student = user.student_account? && Enrollment.exists?(student_id: user.id, active: true, university_id: user.university_id)
    if staff || enrolled_student
      can :index, :announcements
      can :read, Announcement do |announcement|
        course = Course.find_by(id: announcement.course_id)
        next false unless course && course.university_id == user.university_id

        staff_access = SectionStaff.joins(:section).exists?(user_id: user.id, sections: { course_id: course.id }) ||
          CourseCoordinator.exists?(course_id: course.id, user_id: user.id)
        next true if staff_access
        next false unless user.student_account?

        if announcement.section_id
          Enrollment.exists?(student_id: user.id, section_id: announcement.section_id, active: true)
        else
          Enrollment.joins(:section).exists?(student_id: user.id, active: true, sections: { course_id: course.id })
        end
      end
    end

    return unless user.profesor?

    can [ :create, :update ], Announcement do |announcement|
      course = announcement.course
      next false unless course && course.university_id == user.university_id

      coordinator = CourseCoordinator.exists?(course_id: course.id, user_id: user.id)
      teaching = SectionStaff.joins(:section).exists?(user_id: user.id, role: "profesor", sections: { course_id: course.id })
      next false unless coordinator || teaching

      section = announcement.section
      section.nil? || (section.course_id == course.id &&
        (coordinator || SectionStaff.exists?(section_id: section.id, user_id: user.id, role: "profesor")))
    end

    can :destroy, Announcement do |announcement|
      can?(:create, announcement)
    end
  end
end
