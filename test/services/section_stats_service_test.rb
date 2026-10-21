require "test_helper"

# Section figures shown in the course and section overviews (PR #28).
class SectionStatsServiceTest < ActiveSupport::TestCase
  setup do
    @section = sections(:one)
    @student = users(:alumno) # enrolled in sections(:one)
    @classmate = User.create!(first_name: "Compañera", last_name: "Curso", rut: "10000005-9", email: "companera@ucv.test",
      password: "password123", role: "alumno", university: universities(:ucv))
    Enrollment.create!(section: @section, student: @classmate)
  end

  def stats = SectionStatsService.new(@section)

  def evaluation(name, weight) = Evaluation.create!(section: @section, name: name, weight: weight, due_on: Date.new(2026, 11, 5))

  def grade(evaluation, student, score, status: "publicada")
    Grade.create!(evaluation: evaluation, student: student, score: score, status: status, entered_by: users(:ayudante),
                  rejection_comment: (status == "rechazada" ? "Revisa" : nil))
  end

  test "el promedio del alumno pondera solo sus notas publicadas" do
    control = evaluation("Control 2", 20)
    exam = evaluation("Examen", 30)
    grade(control, @student, 6.0)
    grade(exam, @student, 4.0)
    # grades(:one) is a pending 5.5 of the same student: it does not count.

    assert_in_delta 4.8, stats.student_average(@student), 0.001 # (6.0 × 20 + 4.0 × 30) / 50
  end

  test "sin notas publicadas no hay promedio" do
    assert_nil stats.student_average(@student)
    assert_nil stats.average
  end

  test "el promedio de la sección es el promedio de los promedios de sus alumnos" do
    control = evaluation("Control 2", 20)
    grade(control, @student, 6.0)
    grade(control, @classmate, 4.0)

    assert_in_delta 5.0, stats.average, 0.001
  end

  test "la asistencia de la sección es el promedio del porcentaje de sus alumnos" do
    # attendance_sessions(:one): users(:alumno) present; the classmate has no mark, which counts as absent.
    assert_in_delta 50.0, stats.attendance_percentage, 0.001
  end

  test "sin clases registradas no hay porcentaje de asistencia" do
    @section.attendance_sessions.destroy_all

    assert_nil stats.attendance_percentage
  end
end
