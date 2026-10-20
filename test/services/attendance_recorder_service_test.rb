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
