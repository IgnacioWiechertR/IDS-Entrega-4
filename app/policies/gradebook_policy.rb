class GradebookPolicy
  include CanCan::Ability

  def initialize(user)
    if user.profesor? || user.student_account?
      # C11: the profesor and the ayudantes of a section see all its grades with their status.
      can :read_gradebook, Section, section_staffs: { user_id: user.id }
    else
      # The administrativo and the director only see the general grades of a section (its average, in the section
      # summary and in the course overview), never each student's grades (C11). The administrativo has
      # `can :manage, Section` (A18), which covers any action, so it is denied explicitly.
      cannot :read_gradebook, Section
    end
  end
end
