class TeacherAssignmentPolicy
  include CanCan::Ability

  def initialize(user)
    return unless user&.administrativo? && user.university_id.present?

    can :assign_professor, Section, university_id: user.university_id
  end
end
