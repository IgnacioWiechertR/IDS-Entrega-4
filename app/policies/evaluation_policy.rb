class EvaluationPolicy
  include CanCan::Ability

  def initialize(user)
    # Only accounts that can belong to a section's teaching staff (an alumno account can be an ayudante).
    return unless user.profesor? || user.ayudante? || user.alumno?

    # C13: the profesor or the ayudante of the section creates and lists its evaluations.
    can %i[read create], Evaluation, section: { section_staffs: { user_id: user.id } }
  end
end
