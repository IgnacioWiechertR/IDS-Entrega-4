class GradebookPolicy
  include CanCan::Ability

  def initialize(user)
    if user.profesor? || user.student_account?
      # C11: the profesor and the ayudantes of a section see all its grades with their status.
      can :read_gradebook, Section, section_staffs: { user_id: user.id }
    elsif user.director?
      # The director only reads the grades of every section of the active university (Section is scoped to it,
      # A3). They do not enter, approve or reject them.
      can :read_gradebook, Section
    else
      # The administrativo has `can :manage, Section` (A18), and :manage covers any action. But the card says no
      # role sees the grades of a section where it does not take part, so it is denied explicitly.
      cannot :read_gradebook, Section
    end
  end
end
