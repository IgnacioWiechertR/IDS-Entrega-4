class GradeReviewPolicy
  include CanCan::Ability

  def initialize(user)
    return unless user.profesor?

    # C2, C5, C6: only the profesor of the section sees, approves and rejects its preliminary grades.
    can :review_grades, Evaluation, section: { section_staffs: { user_id: user.id, role: "profesor" } }
  end
end
