require "test_helper"
require_relative "../support/university_summary_data"

# D1: the director's end-of-term dashboard, per university and side by side.
class DashboardTest < ActionDispatch::IntegrationTest
  include UniversitySummaryData

  setup do
    @ucv = universities(:ucv)
    @iusa = universities(:iusa)
    create_summary_period(@ucv, "D1-UCV")
    @good = summary_student(@ucv, "buena")
    @bad = summary_student(@ucv, "mala")
    summary_grade(@summary_control, @good, 6.0)
    summary_grade(@summary_exam, @good, 5.0)
    summary_grade(@summary_control, @bad, 3.0)
    summary_class(Date.new(2026, 9, 1), @good => "presente", @bad => "ausente")
  end

  def show_dashboard_of(university)
    sign_in users(:director)
    patch university_selection_path, params: { university_id: university.id }
    get dashboard_path
    assert_response :success
  end

  test "el director ve los indicadores del período de la universidad activa" do
    show_dashboard_of(@ucv)

    assert_select "#university-summary" do
      assert_select "p", text: /Período D1-UCV/
      assert_select ".summary-average", "4,2" # (5.4 + 3.0) / 2, con las notas publicadas
      assert_select ".summary-attendance", "50 %"
    end
  end

  test "con las actas cerradas muestra las tasas de aprobación y reprobación" do
    summary_grade(@summary_exam, @bad, 3.5)
    show_dashboard_of(@ucv)

    assert_select "#university-summary" do
      assert_select ".records-open-alert", count: 0
      assert_select ".summary-approval", "50 %"
      assert_select ".summary-failure", "50 %"
    end
  end

  test "con las actas abiertas muestra una alerta y oculta las tasas definitivas" do
    summary_grade(@summary_exam, @bad, 3.5, status: "pendiente")
    show_dashboard_of(@ucv)

    assert_select "#university-summary" do
      assert_select ".records-open-alert", text: /aún no están cerradas/
      assert_select ".summary-approval", "Actas abiertas"
      assert_select ".summary-failure", "Actas abiertas"
    end
  end

  test "el selector cambia la universidad del resumen" do
    show_dashboard_of(@iusa)

    assert_select "#active-university", text: /#{@iusa.name}/
    assert_select "#university-summary p", text: /Período D1-UCV/, count: 0
  end

  test "la comparación muestra cada universidad por separado, sin mezclar sus datos" do
    show_dashboard_of(@iusa)

    assert_select "#universities-comparison > div", count: University.count
    assert_select "##{ActionView::RecordIdentifier.dom_id(@ucv, :summary)}" do
      assert_select "h3", @ucv.name
      assert_select ".summary-average", "4,2"
      assert_select ".summary-attendance", "50 %"
    end
    assert_select "##{ActionView::RecordIdentifier.dom_id(@iusa, :summary)}" do
      assert_select "h3", @iusa.name
      assert_select "p", text: /Período D1-UCV/, count: 0
    end
  end

  test "el dashboard carga en menos de 3 segundos" do
    sign_in users(:director)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    get dashboard_path
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    assert_response :success
    assert_operator elapsed, :<, 3.0
  end

  test "el dashboard es de solo lectura" do
    show_dashboard_of(@ucv)

    # The only form is the D2 filter, sent with GET.
    assert_select "main form", count: 1
    assert_select "main form#summary-filters[method=get]"
  end

  test "D2: el director filtra el resumen por asignatura y se recalculan los indicadores" do
    other_section, other_exam = create_summary_course(@ucv, "D2-UCV")
    summary_grade(other_exam, summary_student(@ucv, "otra", section: other_section), 7.0)
    show_dashboard_of(@ucv)
    assert_select "#university-summary .summary-average", "5,1" # (5.4 + 3.0 + 7.0) / 3

    get dashboard_path(course_id: other_section.course_id)

    assert_response :success
    assert_select "#university-summary" do
      assert_select ".summary-scope", text: /Asignatura: D2-UCV/
      assert_select ".summary-average", "7,0"
      assert_select "select#course_id option[selected]", text: /D2-UCV/
    end
    assert_select "#summary-filters a", text: "Quitar filtros"
  end

  test "D2: el director filtra por facultad y por período" do
    show_dashboard_of(@ucv)

    get dashboard_path(term_id: @summary_term.id, faculty_id: @summary_faculty.id)

    assert_response :success
    assert_select "#university-summary .summary-scope", text: /Facultad: Facultad D1-UCV/
    assert_select "#university-summary .summary-average", "4,2"
    assert_select "select#term_id option[selected]", text: "Período D1-UCV"
  end

  test "D2: si el filtro no tiene datos se muestra un mensaje" do
    empty_faculty = ActsAsTenant.with_tenant(@ucv) { Faculty.create!(name: "Facultad sin asignaturas") }
    show_dashboard_of(@ucv)

    get dashboard_path(faculty_id: empty_faculty.id)

    assert_select "#university-summary .summary-empty", text: /No hay datos para los filtros seleccionados/
    assert_select "#university-summary .summary-average", count: 0
  end

  test "D2: la comparación entre universidades no usa los filtros" do
    other_section, other_exam = create_summary_course(@ucv, "D2-UCV")
    summary_grade(other_exam, summary_student(@ucv, "otra", section: other_section), 7.0)
    show_dashboard_of(@ucv)

    get dashboard_path(course_id: other_section.course_id)

    assert_select "##{ActionView::RecordIdentifier.dom_id(@ucv, :summary)} .summary-average", "5,1"
  end

  test "D2: los filtros solo ofrecen datos de la universidad activa" do
    iusa_course = ActsAsTenant.with_tenant(@iusa) { Course.first }
    show_dashboard_of(@ucv)

    assert_select "select#course_id option", text: /D1-UCV/
    assert_select "select#course_id option", text: /#{iusa_course.code}/, count: 0
  end

  test "D2: un filtro de otra universidad responde 404" do
    iusa_course = ActsAsTenant.with_tenant(@iusa) { Course.first }
    show_dashboard_of(@ucv)

    get dashboard_path(course_id: iusa_course.id)

    assert_response :not_found
  end

  test "los demás roles no ven el dashboard" do
    { administrativo: accounts_path, profesor: courses_path, ayudante: courses_path, alumno: courses_path }.each do |role, home|
      sign_in users(role)
      get dashboard_path

      assert_redirected_to home, "#{role} no debería ver el dashboard"
      sign_out :user
    end
  end
end
