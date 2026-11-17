class AnnouncementPolicy
  include CanCan::Ability

  def initialize(user)
    # B12: profesores, and student accounts that are ayudantes of some section. An alumno account can be one
    # (Trello A23); a student who only studies sees announcements in B16.
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
