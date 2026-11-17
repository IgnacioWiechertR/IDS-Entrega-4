require "test_helper"

class ConsolidatedReportServiceTest < ActiveSupport::TestCase
  setup do
    @ucv = universities(:ucv)
    @admin = users(:administrativo)
    @profesor = users(:profesor)
    @ayudante = users(:ayudante)

    @term = Term.create!(
      university: @ucv,
      name: "2027-2",
      starts_on: Date.new(2027, 8, 1),
      ends_on: Date.new(2027, 12, 15)
    )
    @course = Course.create!(
      university: @ucv,
      faculty: faculties(:one),
      code: "D4TEST1",
      name: "Bases de Datos"
    )
    @section = Section.create!(
      university: @ucv,
      course: @course,
      term: @term,
      number: 1
    )
    SectionStaff.create!(
      university: @ucv,
      section: @section,
      user: @profesor,
      role: "profesor",
      assigned_by: @admin
    )

    @student_a = User.create!(
      first_name: "Camila", last_name: "Paz", rut: "10000041-5",
      email: "camila.d4@ucv.test", role: "alumno", university: @ucv, password: "password123"
    )
    @student_b = User.create!(
      first_name: "Diego", last_name: "Lagos", rut: "10000042-3",
      email: "diego.d4@ucv.test", role: "alumno", university: @ucv, password: "password123"
    )
    @student_inactive = User.create!(
      first_name: "Luis", last_name: "Retirado", rut: "10000043-1",
      email: "luis.d4@ucv.test", role: "alumno", university: @ucv, password: "password123"
    )

    Enrollment.create!(university: @ucv, section: @section, student: @student_a, active: true)
    Enrollment.create!(university: @ucv, section: @section, student: @student_b, active: true)
    Enrollment.create!(university: @ucv, section: @section, student: @student_inactive, active: false)
  end

  test "calcula promedio ponderado, aprobación, max, min y asistencia solo con notas oficiales y alumnos activos" do
    eval1 = Evaluation.create!(university: @ucv, section: @section, name: "Prueba 1", weight: 30, due_on: Date.new(2027, 9, 15))
    eval2 = Evaluation.create!(university: @ucv, section: @section, name: "Prueba 2", weight: 50, due_on: Date.new(2027, 11, 15))

    # Alumno A: (6.0 * 0.3 + 5.0 * 0.5) / 0.8 = 5.375 -> 5.4 (Aprobado)
    Grade.create!(university: @ucv, evaluation: eval1, student: @student_a, score: 6.0, status: "publicada", entered_by: @ayudante, reviewed_by: @profesor)
    Grade.create!(university: @ucv, evaluation: eval2, student: @student_a, score: 5.0, status: "publicada", entered_by: @ayudante, reviewed_by: @profesor)

    # Alumno B: (3.0 * 0.3 + 3.5 * 0.5) / 0.8 = 3.3125 -> 3.3 (Reprobado); nota pendiente extra (20%) no debe contarse
    Grade.create!(university: @ucv, evaluation: eval1, student: @student_b, score: 3.0, status: "publicada", entered_by: @ayudante, reviewed_by: @profesor)
    Grade.create!(university: @ucv, evaluation: eval2, student: @student_b, score: 3.5, status: "publicada", entered_by: @ayudante, reviewed_by: @profesor)
    eval_pending = Evaluation.create!(university: @ucv, section: @section, name: "Recuperativa", weight: 20, due_on: Date.new(2027, 12, 1))
    Grade.create!(university: @ucv, evaluation: eval_pending, student: @student_b, score: 7.0, status: "pendiente", entered_by: @ayudante)

    # Alumno retirado con 7.0 no debe afectar promedios ni conteos
    Grade.create!(university: @ucv, evaluation: eval1, student: @student_inactive, score: 7.0, status: "publicada", entered_by: @ayudante, reviewed_by: @profesor)

    # Asistencia: 2 sesiones * 2 alumnos activos = 4 marcas esperadas; 2 asistencias => 50.0%
    session1 = AttendanceSession.create!(university: @ucv, section: @section, held_on: Date.new(2026, 8, 10), recorded_by: @profesor)
    session2 = AttendanceSession.create!(university: @ucv, section: @section, held_on: Date.new(2026, 8, 11), recorded_by: @profesor)
    AttendanceRecord.create!(university: @ucv, attendance_session: session1, student: @student_a, status: "presente")
    AttendanceRecord.create!(university: @ucv, attendance_session: session1, student: @student_b, status: "ausente")
    AttendanceRecord.create!(university: @ucv, attendance_session: session2, student: @student_a, status: "presente")
    AttendanceRecord.create!(university: @ucv, attendance_session: session2, student: @student_b, status: "ausente")

    row = ConsolidatedReportService.call(university: @ucv, term_id: @term.id, course_id: @course.id).first

    assert row.has_evaluations
    assert_in_delta 4.3, row.average_grade, 0.05
    assert_in_delta 50.0, row.pass_rate, 0.1
    assert_in_delta 50.0, row.fail_rate, 0.1
    assert_in_delta 5.4, row.max_grade, 0.05
    assert_in_delta 3.3, row.min_grade, 0.05
    assert_in_delta 50.0, row.attendance_rate, 0.1
  end

  test "marca has_evaluations en false y deja métricas de notas en nil cuando no hay evaluaciones" do
    row = ConsolidatedReportService.call(university: @ucv, term_id: @term.id, course_id: @course.id).first

    assert_not row.has_evaluations
    assert_nil row.average_grade
    assert_nil row.pass_rate
    assert_nil row.fail_rate
    assert_nil row.max_grade
    assert_nil row.min_grade
  end

  test "to_csv genera encabezados y valores formateados consistentes" do
    rows = ConsolidatedReportService.call(university: @ucv, term_id: @term.id, course_id: @course.id)
    csv_output = ConsolidatedReportService.to_csv(rows)
    lines = csv_output.lines(chomp: true)

    assert_equal ConsolidatedReportService::CSV_HEADERS.join(";"), lines.first
    assert_match(/\AD4TEST1;Bases de Datos;1;2027-2;#{Regexp.escape(@profesor.name)};Sin datos;/, lines.second)
  end
end
