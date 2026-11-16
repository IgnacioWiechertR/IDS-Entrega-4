class AccountPolicy
  include CanCan::Ability

  # A4: the administrativo creates these accounts. Administrativos and the director are not created from the app.
  CREATABLE_ROLES = %w[alumno ayudante profesor].freeze

  def initialize(user)
    # The accounts panel. The users scaffold stays closed until A4/A5/A6 add their rules.
    can :index, :accounts if user.director? || user.administrativo?

    can :import, :accounts if user.administrativo? && user.university_id.present?

    # A custom action instead of :create, so the closed users scaffold does not open with it.
    can :create_account, User, university_id: user.university_id, role: CREATABLE_ROLES if user.administrativo?

    # A17: Director y administrativo pueden cambiar el rol de cuentas gestionables en su universidad activa.
    if user.director?
      can :change_role, User, role: CREATABLE_ROLES
    elsif user.administrativo? && user.university_id.present?
      can :change_role, User, university_id: user.university_id, role: CREATABLE_ROLES
    end

    can :switch, University if user.director?
  end
end
