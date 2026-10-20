class EnrollmentPolicy
  include CanCan::Ability

  def initialize(user)
    return unless user&.administrativo?

    can :manage, Enrollment, section: { university_id: user.university_id }
  end
end
