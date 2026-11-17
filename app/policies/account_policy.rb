class AccountPolicy
  include CanCan::Ability

  # A4: the administrativo creates these accounts. The director creates only administrativos; nobody creates a
  # director from the app.
  CREATABLE_ROLES = %w[alumno ayudante profesor].freeze
  DIRECTOR_CREATABLE_ROLES = %w[administrativo].freeze

  def initialize(user)
    # The accounts panel. The users scaffold stays closed until A4/A5/A6 add their rules.
    can :index, :accounts if user.director? || user.administrativo?

    can :import, :accounts if user.administrativo? && user.university_id.present?

    # A custom action instead of :create, so the closed users scaffold does not open with it.
    can :create_account, User, university_id: user.university_id, role: CREATABLE_ROLES if user.administrativo?

    # The director sees everything and changes nothing; the only thing it does is create administrativo accounts,
    # in the university picked with the selector.
    if user.director? && (university_id = ActsAsTenant.current_tenant&.id)
      can :create_account, User, university_id: university_id, role: DIRECTOR_CREATABLE_ROLES
    end

    # A17: el administrativo cambia el rol de las cuentas gestionables de su universidad. El director no: solo lee.
    if user.administrativo? && user.university_id.present?
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
