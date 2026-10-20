class AttendancePolicy
  include CanCan::Ability

  def initialize(user)
    return unless user.profesor? || user.student_account?

    # "Asistencia": the sections the user teaches and, for a student account, their own attendance.
    can :index, :attendance

    # B6, B9: only the profesor of a section takes its attendance and sees the whole table.
    can :take_attendance, Section, section_staffs: { user_id: user.id, role: "profesor" }

    # B8, B10: a student sees only their own attendance, in the sections where they are actively enrolled.
    can :read_own_attendance, Section, enrollments: { student_id: user.id, active: true }
  end
end
