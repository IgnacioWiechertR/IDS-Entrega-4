class AccountPolicy
  include CanCan::Ability

  def initialize(user)
    return unless user

    if user.administrativo?
      can :manage, User
      can :index, :accounts
    end
  end
end