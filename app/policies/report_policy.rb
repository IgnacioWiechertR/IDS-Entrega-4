class ReportPolicy
  include CanCan::Ability

  def initialize(user)
    can :read, :dashboard if user.director?
  end
end
