# The terms and faculties of a university are the base of its courses and sections: the administrativo manages
# those of its own university (Entrega 2, "carga administrativa del inicio de cada período"), and the director
# only reads them, in the university picked with the selector (Term and Faculty are scoped to it, A3).
class AcademicStructurePolicy
  include CanCan::Ability

  def initialize(user)
    can :read, [ Term, Faculty ] if user.director?

    return unless user.administrativo? && user.university_id.present?

    can %i[read create update destroy], [ Term, Faculty ], university_id: user.university_id
  end
end
