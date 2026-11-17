class ReportPolicy
  include CanCan::Ability

  def initialize(user)
    can :read, :dashboard if user.director?

    # The director reads every report of the university picked with the selector (the controllers use
    # current_university); the administrativo, those of its own university.
    if user.director?
      can %i[read_grade_statuses read_data_completeness read_consolidated], :reports
    end
    can :read_grade_statuses, :reports if user.administrativo? && user.university_id.present?
    can :read_data_completeness, :reports if user.administrativo? && user.university_id.present?
    can :read_consolidated, :reports if user.administrativo? && user.university_id.present?
  end
end
