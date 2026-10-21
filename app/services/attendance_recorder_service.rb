# Saves the attendance of a section on one date (B6). There is one session per date, so saving a date
# again corrects its marks instead of duplicating them, and recorded_by keeps who saved it last.
class AttendanceRecorderService
  attr_reader :session

  def initialize(section:, held_on:, recorded_by:)
    @section = section
    @session = section.attendance_sessions.find_or_initialize_by(held_on: held_on)
    @session.recorded_by = recorded_by
  end

  # statuses: { student_id => "presente" | "ausente" }. Only students actively enrolled in the section
  # are marked; any other id or value is ignored. Returns false if the date is not valid.
  def call(statuses)
    AttendanceSession.transaction do
      @session.save!
      @section.active_students.each do |student|
        status = statuses[student.id.to_s]
        next unless AttendanceRecord.statuses.key?(status)

        @session.attendance_records.find_or_initialize_by(student: student).update!(status: status)
      end
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end
end
