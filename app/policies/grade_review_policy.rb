class GradeReviewPolicy
  include CanCan::Ability

  def initialize(user)
    return unless user.profesor?

    # C2, C5, C6: only the profesor of the section sees, approves and rejects its preliminary grades.
    can :review_grades, Evaluation, section: { section_staffs: { user_id: user.id, role: "profesor" } }

    # C8 (Trello): only the profesor who rejected the grades edits the comment, while they are still rejected and
    # while they still teach the section.
    can :edit_rejection_comment, Grade, status: "rechazada", reviewed_by_id: user.id,
      evaluation: { section: { section_staffs: { user_id: user.id, role: "profesor" } } }
  end
end
