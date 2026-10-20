require "test_helper"

class AttendanceRecordTest < ActiveSupport::TestCase
  test "la marca es presente o ausente" do
    assert_equal %w[presente ausente], AttendanceRecord.statuses.keys

    record = AttendanceRecord.new(attendance_session: attendance_sessions(:one), student: users(:ayudante), status: "atrasado")
    assert_not record.valid?
    assert record.errors.added?(:status, :inclusion, value: "atrasado")
  end

  test "un alumno tiene una sola marca por clase" do
    duplicate = AttendanceRecord.new(attendance_session: attendance_sessions(:one), student: users(:alumno), status: "ausente")

    assert_not duplicate.valid?
    assert duplicate.errors.added?(:student_id, :taken, value: users(:alumno).id)
  end
end
