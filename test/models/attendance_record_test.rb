require "test_helper"

class AttendanceRecordTest < ActiveSupport::TestCase
  test "la marca es presente o ausente" do
    assert_equal %w[presente ausente], AttendanceRecord.statuses.keys

    record = AttendanceRecord.new(attendance_session: attendance_sessions(:one), student: users(:ayudante), status: "atrasado")
    assert_not record.valid?
    assert record.errors.added?(:status, :inclusion, value: "atrasado")
  end

  test "cambiar una marca guardada la deja corregida por quien la cambió" do
    record = attendance_records(:one)
    assert_not record.corrected?

    record.mark!("presente", by: users(:profesor))
    assert_not record.corrected?, "guardar la misma marca no es una corrección"

    record.mark!("ausente", by: users(:profesor))
    assert record.reload.corrected?
    assert_equal users(:profesor), record.corrected_by
    assert_not_nil record.corrected_at
  end

  test "quien corrige una marca pertenece a la universidad de la clase" do
    record = attendance_records(:one)
    record.corrected_by = ActsAsTenant.without_tenant { users(:profesor_iusa) }

    assert_not record.valid?
    assert record.errors.added?(:corrected_by, :must_match_university)
  end

  test "un alumno tiene una sola marca por clase" do
    duplicate = AttendanceRecord.new(attendance_session: attendance_sessions(:one), student: users(:alumno), status: "ausente")

    assert_not duplicate.valid?
    assert duplicate.errors.added?(:student_id, :taken, value: users(:alumno).id)
  end
end
