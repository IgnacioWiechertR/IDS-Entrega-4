class AnnouncementPolicy
  include CanCan::Ability

  def initialize(user)
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
