require "test_helper"
require_relative "../support/university_summary_data"

# End-of-term summary of a university for the director's dashboard (D1).
class UniversitySummaryServiceTest < ActiveSupport::TestCase
  include UniversitySummaryData

  setup do
    @university = University.create!(name: "Universidad D1", slug: "d1-local")
    @other_university = University.create!(name: "Otra universidad D1", slug: "d1-otra")
    create_summary_period(@university, "D1-LOCAL")
    @good = summary_student(@university, "buena")
    @bad = summary_student(@university, "mala")
  end

  def summary(university = @university) = UniversitySummaryService.new(university)

  def publish_all_grades
    summary_grade(@summary_control, @good, 6.0)
    summary_grade(@summary_exam, @good, 5.0)   # (6.0 × 40 + 5.0 × 60) / 100 = 5.4
    summary_grade(@summary_control, @bad, 3.0)
    summary_grade(@summary_exam, @bad, 3.5)    # (3.0 × 40 + 3.5 × 60) / 100 = 3.3
  end

  test "el resumen es del período vigente de la universidad" do
    assert_equal @summary_term, summary.term
  end

  test "sin período vigente se usa el período más reciente" do
    ActsAsTenant.with_tenant(@university) do
      @summary_term.update!(current: false)
      Term.create!(name: "Período anterior", starts_on: Date.new(2025, 3, 1), ends_on: Date.new(2025, 7, 31))
    end

    assert_equal @summary_term, summary.term
  end

  test "una universidad sin períodos no tiene indicadores" do
    empty = University.create!(name: "Universidad sin períodos", slug: "d1-vacia")
    result = summary(empty)

    assert_not result.term?
    assert_nil result.average
    assert_nil result.attendance_percentage
    assert_nil result.approval_rate
  end

  test "el promedio general es el promedio de los promedios ponderados de las notas oficiales" do
    publish_all_grades

    assert_in_delta 4.35, summary.average, 0.001 # (5.4 + 3.3) / 2
  end

  test "aprueba quien tiene promedio ponderado de al menos 4.0" do
    publish_all_grades
    almost = summary_student(@university, "justa")
    summary_grade(@summary_control, almost, 4.0)
    summary_grade(@summary_exam, almost, 4.0)
    result = summary

    assert result.records_closed?
    assert_equal 2, result.approved_count
    assert_equal 1, result.failed_count
    assert_in_delta 66.667, result.approval_rate, 0.001
    assert_in_delta 33.333, result.failure_rate, 0.001
  end

  test "con notas sin publicar las actas siguen abiertas y no hay tasas definitivas" do
    summary_grade(@summary_control, @good, 6.0)
    summary_grade(@summary_exam, @good, 5.0)
    summary_grade(@summary_control, @bad, 3.0)
    summary_grade(@summary_exam, @bad, 3.5, status: "pendiente")
    result = summary

    assert_not result.records_closed?
    assert_nil result.approval_rate
    assert_nil result.failure_rate
    assert_in_delta 4.2, result.average, 0.001 # (5.4 + 3.0) / 2: only published grades count
  end

  test "un período sin evaluaciones no tiene las actas cerradas" do
    ActsAsTenant.with_tenant(@university) { Evaluation.where(section: @summary_section).destroy_all }

    assert_not summary.records_closed?
  end

  test "la asistencia global cuenta las clases de los alumnos activos" do
    inactive = summary_student(@university, "retirada", active: false)
    summary_class(Date.new(2026, 9, 1), @good => "presente", @bad => "presente", inactive => "presente")
    summary_class(Date.new(2026, 9, 8), @good => "presente", @bad => "ausente", inactive => "presente")

    assert_in_delta 75.0, summary.attendance_percentage, 0.001 # 3 of 4; the withdrawn student does not count
  end

  test "una clase sin marca para el alumno cuenta como ausencia" do
    summary_class(Date.new(2026, 9, 1), @good => "presente")

    assert_in_delta 50.0, summary.attendance_percentage, 0.001
  end

  test "sin clases registradas no hay porcentaje de asistencia" do
    assert_nil summary.attendance_percentage
  end

  test "no mezcla los datos de otra universidad" do
    publish_all_grades
    summary_class(Date.new(2026, 9, 1), @good => "presente", @bad => "presente")

    create_summary_period(@other_university, "D1-OTRA")
    other_student = summary_student(@other_university, "otra")
    summary_grade(@summary_control, other_student, 7.0)
    summary_grade(@summary_exam, other_student, 7.0, status: "pendiente")
    summary_class(Date.new(2026, 9, 1), other_student => "ausente")

    local = summary
    other = summary(@other_university)

    assert_in_delta 4.35, local.average, 0.001
    assert_in_delta 100.0, local.attendance_percentage, 0.001
    assert local.records_closed?
    assert_in_delta 7.0, other.average, 0.001
    assert_in_delta 0.0, other.attendance_percentage, 0.001
    assert_not other.records_closed?
  end

  test "el resumen se calcula en su universidad aunque la universidad activa sea otra" do
    publish_all_grades

    ActsAsTenant.with_tenant(@other_university) do
      assert_in_delta 4.35, summary.average, 0.001
    end
  end
end
