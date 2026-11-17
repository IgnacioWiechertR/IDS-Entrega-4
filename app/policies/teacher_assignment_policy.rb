class TeacherAssignmentPolicy
  include CanCan::Ability

  def initialize(user)
    return unless user&.university_id.present?

    # A22: the administrativo assigns in every section of their university.
    can :assign_professor, Section, university_id: user.university_id if user.administrativo?

    # A22: the profesor who coordinates a course assigns in its sections of the term they coordinate. The rule
    # only exists for coordinators, so `can?(:assign_professor, Section)` (menu, index) stays false for the rest.
    return unless user.profesor? && CourseCoordinator.exists?(user_id: user.id, university_id: user.university_id)

    can :assign_professor, Section, Section.coordinated_by(user) do |section|
      section.coordinated_by?(user)
    end
  end
end
