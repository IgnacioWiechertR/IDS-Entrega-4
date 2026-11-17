require "test_helper"
require_relative "../support/university_summary_data"

# D2: the summary of a university filtered by term, faculty and course.
class UniversitySummaryFiltersTest < ActiveSupport::TestCase
  include UniversitySummaryData

  setup do
    @university = University.create!(name: "Universidad D2", slug: "d2-local")
    create_summary_period(@university, "D2-BASE")
    good = summary_student(@university, "buena")
    bad = summary_student(@university, "mala")
    summary_grade(@summary_control, good, 6.0)
    summary_grade(@summary_exam, good, 5.0)    # 5.4
    summary_grade(@summary_control, bad, 3.0)
    summary_grade(@summary_exam, bad, 3.5)     # 3.3

    # Another course of the same period, in another faculty: one student with a 7.0.
    @other_section, other_exam = create_summary_course(@university, "D2-OTRA")
    summary_grade(other_exam, summary_student(@university, "otra", section: @other_section), 7.0)
  end

  def summary(**filters) = UniversitySummaryService.new(@university, **filters)

  test "sin filtros el resumen incluye todas las asignaturas del período" do
    result = summary

    assert_not result.filtered?
    assert_in_delta 5.233, result.average, 0.001 # (5.4 + 3.3 + 7.0) / 3
  end

  test "el filtro por asignatura recalcula los indicadores" do
    result = summary(course_id: @summary_course.id)

    assert result.filtered?
    assert_equal @summary_course, result.course
    assert_in_delta 4.35, result.average, 0.001
    assert_in_delta 50.0, result.approval_rate, 0.001
  end

  test "el filtro por facultad deja solo sus asignaturas" do
    result = summary(faculty_id: @other_section.course.faculty_id)

    assert_in_delta 7.0, result.average, 0.001
    assert_in_delta 100.0, result.approval_rate, 0.001
  end

  test "el filtro por período cambia el período del resumen" do
    past = ActsAsTenant.with_tenant(@university) do
      Term.create!(name: "Período anterior D2", starts_on: Date.new(2026, 3, 1), ends_on: Date.new(2026, 7, 15))
    end
    past_section, past_exam = create_summary_course(@university, "D2-PASADO", term: past)
    summary_grade(past_exam, summary_student(@university, "pasada", section: past_section), 2.0)

    result = summary(term_id: past.id)

    assert_equal past, result.term
    assert_in_delta 2.0, result.average, 0.001
    assert_in_delta 100.0, result.failure_rate, 0.001
  end

  test "un filtro sin datos deja el resumen vacío" do
    empty_faculty = ActsAsTenant.with_tenant(@university) { Faculty.create!(name: "Facultad sin asignaturas") }
    result = summary(faculty_id: empty_faculty.id)

    assert result.empty?
    assert_nil result.average
    assert_nil result.attendance_percentage
  end

  test "una asignatura que no es de la facultad elegida no tiene datos" do
    result = summary(faculty_id: @other_section.course.faculty_id, course_id: @summary_course.id)

    assert result.empty?
  end

  test "un período, facultad o asignatura de otra universidad no se encuentra" do
    other = University.create!(name: "Otra universidad D2", slug: "d2-otra")
    create_summary_period(other, "D2-AJENA")

    assert_raises(ActiveRecord::RecordNotFound) { summary(term_id: @summary_term.id) }
    assert_raises(ActiveRecord::RecordNotFound) { summary(faculty_id: @summary_faculty.id) }
    assert_raises(ActiveRecord::RecordNotFound) { summary(course_id: @summary_course.id) }
  end
end
