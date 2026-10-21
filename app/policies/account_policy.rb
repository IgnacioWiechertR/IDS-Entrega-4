class AccountPolicy
  include CanCan::Ability

  # A4: the administrativo creates these accounts. Administrativos and the director are not created from the app.
  CREATABLE_ROLES = %w[alumno ayudante profesor].freeze

  def initialize(user)
    # The accounts panel. The users scaffold stays closed until A4/A5/A6 add their rules.
    can :index, :accounts if user.director? || user.administrativo?

    # A custom action instead of :create, so the closed users scaffold does not open with it.
    can :create_account, User, university_id: user.university_id, role: CREATABLE_ROLES if user.administrativo?

    # Only the director works across universities and picks the active one (A3).
    can :switch, University if user.director?
  end
end
