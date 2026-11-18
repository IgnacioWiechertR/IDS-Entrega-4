require "test_helper"

module Reports
  class ConsolidatedTest < ActionDispatch::IntegrationTest
    DENIED = "No tienes permiso para ver esa página.".freeze

    setup do
      @ucv = universities(:ucv)
      @iusa = universities(:iusa)
      @admin = users(:administrativo)
      @profesor = users(:profesor)
      @ayudante = users(:ayudante)
      @alumno = users(:alumno)

      @term = Term.create!(university: @ucv, name: "2028-2", starts_on: Date.new(2028, 8, 1), ends_on: Date.new(2028, 12, 15))
      @course = Course.create!(university: @ucv, faculty: faculties(:one), code: "INTD4", name: "Redes")
      @section = Section.create!(university: @ucv, course: @course, term: @term, number: 1)
      Enrollment.create!(university: @ucv, section: @section, student: @alumno, active: true)
    end

    test "oculta los gráficos y muestra mensaje cuando no hay evaluaciones registradas" do
      sign_in @admin
      get reports_consolidated_path(term_id: @term.id, course_id: @course.id)

      assert_response :success
      assert_select "#consolidated-charts", count: 0
      assert_select "#no-evaluations-message", text: /No hay evaluaciones con notas oficiales/
      assert_select "tr#consolidated-section-#{@section.id}"
    end

    test "muestra gráficos y métricas cuando existen evaluaciones con notas oficiales" do
      evaluation = Evaluation.create!(university: @ucv, section: @section, name: "Certamen 1", weight: 100, due_on: Date.new(2028, 10, 15))
      Grade.create!(university: @ucv, evaluation: evaluation, student: @alumno, score: 5.8, status: "publicada", entered_by: @ayudante, reviewed_by: @profesor)

      sign_in @admin
      get reports_consolidated_path(term_id: @term.id, course_id: @course.id)

      assert_response :success
      assert_select "#consolidated-charts", count: 1
      assert_select "#no-evaluations-message", count: 0
      assert_select "tr#consolidated-section-#{@section.id} td", text: "5.8"
      assert_select "a[href=?]", reports_consolidated_path(format: :csv, term_id: @term.id, course_id: @course.id), text: "Exportar CSV"
    end

    test "exporta CSV con los filtros aplicados y solo con datos de la universidad activa" do
      evaluation = Evaluation.create!(university: @ucv, section: @section, name: "Certamen 1", weight: 100, due_on: Date.new(2028, 10, 15))
      Grade.create!(university: @ucv, evaluation: evaluation, student: @alumno, score: 6.2, status: "publicada", entered_by: @ayudante, reviewed_by: @profesor)

      ActsAsTenant.with_tenant(@iusa) do
        iusa_course = Course.create!(university: @iusa, faculty: Faculty.first!, code: "IUSACSV", name: "Curso Ajeno")
        iusa_term = Term.create!(university: @iusa, name: "2028-2", starts_on: Date.new(2028, 8, 1), ends_on: Date.new(2028, 12, 15))
        Section.create!(university: @iusa, course: iusa_course, term: iusa_term, number: 1)
      end

      sign_in @admin
      get reports_consolidated_path(format: :csv, term_id: @term.id, course_id: @course.id)

      assert_response :success
      assert_equal "text/csv; charset=utf-8", response.content_type
      assert_includes response.headers["Content-Disposition"], "attachment"
      assert_includes response.body, "INTD4;Redes;1;2028-2"
      assert_includes response.body, "6.2;100.0%;0.0%;6.2;6.2"
      assert_not_includes response.body, "IUSACSV"
    end

    test "los demás roles no pueden acceder ni exportar el reporte consolidado" do
      %i[profesor ayudante alumno].each do |fixture|
        sign_in users(fixture)

        get reports_consolidated_path
        assert_response :redirect
        assert_equal DENIED, flash[:alert]

        get reports_consolidated_path(format: :csv)
        assert_response :redirect
        assert_equal DENIED, flash[:alert]

        sign_out :user
      end
    end

    test "la pantalla y el CSV excluyen asistencias de alumnos retirados y conservan el historial" do
      enrollment = Enrollment.create!(section: @section, student: @ayudante, active: true)
      session = AttendanceSession.create!(section: @section, held_on: Date.current, recorded_by: @profesor)
      [ @alumno, @ayudante ].each do |student|
        AttendanceRecord.create!(attendance_session: session, student: student, status: "presente")
      end
      enrollment.update!(active: false)
      sign_in @admin

      get reports_consolidated_path(term_id: @term.id, course_id: @course.id)

      assert_response :success
      assert_select "tr#consolidated-section-#{@section.id} td:last-child", text: "100.0%"

      get reports_consolidated_path(format: :csv, term_id: @term.id, course_id: @course.id)

      assert_response :success
      rows = CSV.parse(response.body, headers: true, col_sep: ";")
      assert_equal 1, rows.size
      assert_equal "100.0%", rows.first["% Asistencia"]
      assert_equal 2, ActsAsTenant.with_tenant(@ucv) { session.attendance_records.count }
    end
  end
end
