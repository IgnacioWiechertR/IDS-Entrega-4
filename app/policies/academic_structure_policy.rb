# The terms of a university are the base of its sections: the administrativo manages those of its own university
# (Entrega 2, "carga administrativa del inicio de cada período"), and the director only reads them, in the
# university picked with the selector (Term is scoped to it, A3).
class AcademicStructurePolicy
  include CanCan::Ability

  def initialize(user)
    can :read, [ Term ] if user.director?

    return unless user.administrativo? && user.university_id.present?

    can %i[read create update destroy], [ Term ], university_id: user.university_id
  end
end
