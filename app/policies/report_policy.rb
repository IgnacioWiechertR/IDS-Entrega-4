class ReportPolicy
  include CanCan::Ability

  def initialize(user)
    can :read, :dashboard if user.director?
    can :read_grade_statuses, :reports if user.administrativo? && user.university_id.present?
    can :read_data_completeness, :reports if user.administrativo? && user.university_id.present?
    can :read_consolidated, :reports if user.administrativo? && user.university_id.present?
  end
end
