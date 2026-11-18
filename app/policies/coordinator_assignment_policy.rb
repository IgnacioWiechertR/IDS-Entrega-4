class CoordinatorAssignmentPolicy
  include CanCan::Ability

  def initialize(user)
    return unless user && (user.director? || user.administrativo?)

    university_id = user.director? ? ActsAsTenant.current_tenant&.id : user.university_id
    return unless university_id

    # The director sees the coordinators of the active university but does not assign them: it only reads.
    can :index, CourseCoordinator, university_id: university_id
    can :create, CourseCoordinator, university_id: university_id if user.administrativo?
  end
end
