class AttendancePolicy
  include CanCan::Ability

  def initialize(user)
    # The whole attendance table of a section, read-only (B9 without taking attendance). Section is scoped to the
    # active university (A3), so the director's rule never reaches the other university.
    can :read_attendance_sheet, Section if user.director?
    can :read_attendance_sheet, Section, university_id: user.university_id if user.administrativo?

    return unless user.profesor? || user.student_account?

    # "Asistencia": the sections the user teaches and, for a student account, their own attendance.
    can :index, :attendance

    # B6, B9: only the profesor of a section takes its attendance.
    can :take_attendance, Section, section_staffs: { user_id: user.id, role: "profesor" }

    # The profesor and the ayudantes of a section see its whole table; the ayudante does not take it (B6).
    can :read_attendance_sheet, Section, section_staffs: { user_id: user.id }

    # A coordinator sees the table of every section of the courses they coordinate.
    can :read_attendance_sheet, Section, course: { course_coordinators: { user_id: user.id } } if user.profesor?

    # B8, B10: a student sees only their own attendance, in the sections where they are actively enrolled.
    can :read_own_attendance, Section, enrollments: { student_id: user.id, active: true }
  end
end
