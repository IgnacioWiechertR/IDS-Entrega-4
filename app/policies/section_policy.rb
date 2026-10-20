class SectionPolicy
  include CanCan::Ability

  def initialize(user)
    # Épicas A18, A19, A20, A21: El administrativo puede gestionar las secciones de su universidad
    if user.administrativo?
      # Permite crear, ver, editar y eliminar secciones de su universidad (A18, A19, A20, A21)
    can :manage, Section

    # El profesor coordinador puede administrar las secciones de su asignatura (se implementará después)
    if user.profesor?
      # can :manage, Section, ...
    end
  end
end