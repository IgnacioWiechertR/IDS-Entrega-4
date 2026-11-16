require "test_helper"

class AttendanceRecorderServiceTest < ActiveSupport::TestCase
  setup do
    @section = sections(:one)
    @student = users(:alumno)
  end

  def recorder(held_on)
    AttendanceRecorderService.new(section: @section, held_on: held_on, recorded_by: users(:profesor))
  end

  test "guarda la clase con la marca de cada alumno inscrito" do
    service = recorder(Date.new(2026, 10, 19))

    assert service.call(@student.id.to_s => "ausente")
    assert_equal users(:profesor), service.session.recorded_by
    assert_equal "ausente", service.session.attendance_records.find_by!(student: @student).status
  end

  test "guardar de nuevo la misma fecha corrige las marcas sin duplicarlas" do
    held_on = attendance_sessions(:one).held_on

    assert_no_difference [ "AttendanceSession.count", "AttendanceRecord.count" ] do
      assert recorder(held_on).call(@student.id.to_s => "ausente")
    end
    assert_equal "ausente", attendance_records(:one).reload.status
  end

  test "cambiar una marca guardada registra quién la corrigió y cuándo, y conserva quién tomó la asistencia" do
    session = attendance_sessions(:one)
    corrector = User.create!(first_name: "Otra", last_name: "Profesora", rut: "66666666-6", email: "otra.profesora@ucv.test",
      role: "profesor", university: universities(:ucv), password: "password123")

    freeze_time do
      service = AttendanceRecorderService.new(section: @section, held_on: session.held_on, recorded_by: corrector)
      assert service.call(@student.id.to_s => "ausente")

      record = attendance_records(:one).reload
      assert record.corrected?
      assert_equal corrector, record.corrected_by
      assert_equal Time.current, record.corrected_at
    end
    assert_equal users(:profesor), session.reload.recorded_by
  end

  test "guardar de nuevo sin cambiar la marca no cuenta como corrección" do
    assert recorder(attendance_sessions(:one).held_on).call(@student.id.to_s => "presente")

    record = attendance_records(:one).reload
    assert_not record.corrected?
    assert_nil record.corrected_at
  end

  test "la primera marca de un alumno en una clase ya registrada no es una corrección" do
    attendance_records(:one).destroy!

    assert recorder(attendance_sessions(:one).held_on).call(@student.id.to_s => "ausente")
    assert_not attendance_sessions(:one).attendance_records.find_by!(student: @student).corrected?
  end

  test "ignora a quienes no están inscritos y las marcas que no son presente o ausente" do
    service = recorder(Date.new(2026, 10, 19))

    assert service.call(users(:ayudante).id.to_s => "presente", @student.id.to_s => "atrasado")
    assert_empty service.session.attendance_records
  end

  test "no registra asistencia de una fecha futura" do
    service = recorder(Date.current + 1)

    assert_no_difference "AttendanceSession.count" do
      assert_not service.call(@student.id.to_s => "presente")
    end
    assert service.session.errors.added?(:held_on, :in_the_future)
  end
end
