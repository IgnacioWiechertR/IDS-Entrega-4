class AccountPolicy
  include CanCan::Ability

  def initialize(user)
    # The accounts panel. The users scaffold stays closed until A4/A5/A6 add their rules.
    can :index, :accounts if user.director? || user.administrativo?

    # Only the director works across universities and picks the active one (A3).
    can :switch, University if user.director?
  end
end
