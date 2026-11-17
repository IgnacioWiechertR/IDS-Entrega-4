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

    assert_select "main form", count: 0
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
