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

    # The administrativo edits the data of the accounts it can create, in its own university. A custom action,
    # like :create_account, so the users scaffold stays closed.
    if user.administrativo? && user.university_id.present?
      can :update_account, User, university_id: user.university_id, role: CREATABLE_ROLES
    end

    # Deleting an account deactivates it: the person can no longer sign in and its history stays. Only the
    # administrativo deletes, and only accounts of its own university; reactivating undoes a deletion by mistake.
    if user.administrativo? && user.university_id.present?
      can %i[destroy_account reactivate_account], User, university_id: user.university_id, role: CREATABLE_ROLES
    end

    cannot %i[destroy_account reactivate_account], User, id: user.id

    can :switch, University if user.director?
  end
end
