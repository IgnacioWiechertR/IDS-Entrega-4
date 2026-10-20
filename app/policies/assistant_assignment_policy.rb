class AssistantAssignmentPolicy
  include CanCan::Ability

  def initialize(user)
    return unless user&.profesor? || user&.administrativo?

    can :manage, SectionStaff, section: { university_id: user.university_id } if user.administrativo?

    can :manage, SectionStaff, section: { course: { course_coordinators: { user_id: user.id } } } if user.profesor?
  end
end
