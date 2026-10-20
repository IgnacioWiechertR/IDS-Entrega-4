# Attendance % of a section (B8): classes the student was present at / classes recorded in the section.
# A recorded class without a mark for the student (for example, enrolled afterwards) counts as absent.
class AttendanceCalculatorService
  def initialize(section)
    @section = section
  end

  # Classes with attendance taken, oldest first.
  def sessions
    @sessions ||= @section.attendance_sessions.order(:held_on).to_a
  end

  def students
    @students ||= @section.active_students.to_a
  end

  # "presente", "ausente" or nil when the student has no mark that day.
  def status(student, session)
    session && marks[[ student.id, session.id ]]
  end

  def present_count(student)
    sessions.count { |session| status(student, session) == "presente" }
  end

  # nil while no class has been recorded, so the views say so instead of showing 0 %.
  def percentage(student)
    return if sessions.empty?

    present_count(student) * 100.0 / sessions.size
  end

  private

  def marks
    @marks ||= AttendanceRecord.where(attendance_session_id: sessions.map(&:id))
      .pluck(:student_id, :attendance_session_id, :status)
      .to_h { |student_id, session_id, status| [ [ student_id, session_id ], status ] }
  end
end
