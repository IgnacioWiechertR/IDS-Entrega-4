require "test_helper"

module Reports
  class GradeStatusesTest < ActionDispatch::IntegrationTest
    DENIED = "No tienes permiso para ver esa página.".freeze

    test "el administrativo ve el conteo de notas por sección solo de su universidad y el enlace al consolidado" do
      ucv = universities(:ucv)
      iusa = universities(:iusa)

      term = Term.create!(university: ucv, name: "2028-1", starts_on: Date.new(2028, 3, 1), ends_on: Date.new(2028, 7, 15))
      course = Course.create!(university: ucv, faculty: faculties(:one), code: "INTD3", name: "Sistemas Operativos")
      section = Section.create!(university: ucv, course: course, term: term, number: 1)

      iusa_section = ActsAsTenant.with_tenant(iusa) do
        iusa_course = Course.create!(university: iusa, faculty: Faculty.first!, code: "IUSAD3", name: "Anatomía II")
        iusa_term = Term.create!(university: iusa, name: "2028-1", starts_on: Date.new(2028, 3, 1), ends_on: Date.new(2028, 7, 15))
        Section.create!(university: iusa, course: iusa_course, term: iusa_term, number: 1)
      end

      sign_in users(:administrativo)
      get reports_grade_statuses_path(term_id: term.id)

      assert_response :success
      assert_select "nav a[href=?]", reports_grade_statuses_path, text: "Notas"
      assert_select "a[href=?]", reports_consolidated_path(term_id: term.id), text: "Reporte consolidado"
      assert_select "tr#section-grade-status-#{section.id}", text: /INTD3/
      assert_select "tr#section-grade-status-#{iusa_section.id}", count: 0
    end

    test "los demás roles no pueden acceder a estado de notas" do
      %i[director profesor ayudante alumno].each do |fixture|
        sign_in users(fixture)
        get reports_grade_statuses_path
        assert_response :redirect
        assert_equal DENIED, flash[:alert], "#{fixture} no debería acceder a estado de notas"
        sign_out :user
      end
    end
  end
end
