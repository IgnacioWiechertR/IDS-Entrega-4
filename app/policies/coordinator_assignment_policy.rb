class CoordinatorAssignmentPolicy
  include CanCan::Ability

  def initialize(user)
    return unless user && (user.director? || user.administrativo?)

    university_id = user.director? ? ActsAsTenant.current_tenant&.id : user.university_id
    return unless university_id

    can %i[ index create ], CourseCoordinator, university_id: university_id
  end
end
