class SectionPolicy
  include CanCan::Ability

  def initialize(user)
    return unless user

    # Permisos para Administrativo (Épica A19, A18, A20, A21)
    if user.role == 'administrativo'
      # Puede ver el listado de secciones (:index) y ver detalles (:show)
      # Falta ajustar el filtro por universidad, pero esto arreglará el error inicial
      can :read, Section
    end
    
    # Aquí luego agregaremos los permisos para el profesor coordinador
  end
end