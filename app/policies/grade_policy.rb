class GradePolicy
  include CanCan::Ability

  def initialize(user)
    # Only student accounts can be ayudantes (an alumno account can assist another course).
    return unless user.student_account?

    # C1 (Trello): only the ayudantes of the section enter preliminary grades; the profesor approves or rejects them.
    can :enter_grades, Evaluation, section: { section_staffs: { user_id: user.id, role: "ayudante" } }

    # C10: a student sees their own official grades. The controller always reads them from current_user.
    # There is no `can :read, Grade` on purpose: the closed /grades scaffold lists Grade.all.
    can :read, :my_grades
  end
end
