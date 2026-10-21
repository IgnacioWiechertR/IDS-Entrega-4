require "test_helper"

class AttendanceCalculatorServiceTest < ActiveSupport::TestCase
  setup do
    @section = sections(:one)
    @student = users(:alumno)
  end

  def take_attendance(held_on, status = nil)
    session = AttendanceSession.create!(section: @section, held_on: held_on, recorded_by: users(:profesor))
    session.attendance_records.create!(student: @student, status: status) if status
  end

  test "el porcentaje es clases presentes sobre clases registradas en la sección" do
    take_attendance(Date.new(2026, 10, 16), "presente")
    take_attendance(Date.new(2026, 10, 17), "ausente")
    calculator = AttendanceCalculatorService.new(@section)

    assert_equal 2, calculator.present_count(@student)
    assert_in_delta 66.67, calculator.percentage(@student), 0.01
  end

  test "una clase sin marca del alumno cuenta como ausente" do
    take_attendance(Date.new(2026, 10, 19))
    calculator = AttendanceCalculatorService.new(@section)

    assert_nil calculator.status(@student, calculator.sessions.last)
    assert_in_delta 50.0, calculator.percentage(@student), 0.01
  end

  test "sin clases registradas no hay porcentaje, en vez de 0 %" do
    @section.attendance_sessions.destroy_all

    assert_nil AttendanceCalculatorService.new(@section).percentage(@student)
  end

  test "la lista tiene solo a los alumnos con inscripción activa" do
    assert_equal [ @student ], AttendanceCalculatorService.new(@section).students

    enrollments(:one).update!(active: false)
    assert_empty AttendanceCalculatorService.new(@section).students
  end
end
