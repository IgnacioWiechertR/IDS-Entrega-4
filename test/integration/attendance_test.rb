require "test_helper"

class AttendanceTest < ActionDispatch::IntegrationTest
  setup { @section = sections(:one) }

  def mark(student_status, held_on: Date.current)
    patch section_attendance_path(@section), params: { attendance: { held_on: held_on.iso8601, statuses: student_status } }
  end

  def in_ucv(&block) = ActsAsTenant.with_tenant(universities(:ucv), &block)

  test "el profesor marca la asistencia de hoy y se actualiza el porcentaje de cada alumno" do
    sign_in users(:profesor)

    get edit_section_attendance_path(@section)
    assert_response :success
    assert_select "input[type=date][value=?]", Date.current.iso8601
    assert_select "#attendance-list", text: /Alumno UCV/

    assert_difference "AttendanceSession.count", 1 do
      mark({ users(:alumno).id => "ausente" })
    end
    assert_redirected_to section_attendance_path(@section)
    follow_redirect!
    assert_select "#attendance-table tbody tr", text: /Alumno UCV.*50\s?%/m
  end

  test "el profesor ve la tabla de alumnos por fechas y desde una fecha puede corregir sus marcas" do
    held_on = attendance_sessions(:one).held_on
    sign_in users(:profesor)

    get section_attendance_path(@section)
    assert_select "#attendance-table thead a[href=?]", edit_section_attendance_path(@section, date: held_on.iso8601)
    assert_select "#attendance-table tbody tr", text: /Alumno UCV.*P.*100\s?%/m

    get edit_section_attendance_path(@section, date: held_on.iso8601)
    assert_select "#already-recorded"
    assert_select "input[type=radio][value=presente][checked]"

    assert_no_difference "AttendanceRecord.count" do
      mark({ users(:alumno).id => "ausente" }, held_on: held_on)
    end
    assert_equal "ausente", attendance_records(:one).reload.status
  end

  test "una sección sin matrículas activas no se puede guardar" do
    in_ucv { enrollments(:one).update!(active: false) }
    sign_in users(:profesor)

    get edit_section_attendance_path(@section)
    assert_select "#no-students", text: /Sección sin matrículas activas/
    assert_select "input[type=submit][value=?][disabled]", "Guardar asistencia"

    assert_no_difference "AttendanceSession.count" do
      mark({})
    end
    assert_equal "Sección sin matrículas activas.", flash[:alert]
  end

  test "una fecha futura no se puede guardar" do
    sign_in users(:profesor)

    assert_no_difference "AttendanceSession.count" do
      mark({ users(:alumno).id => "presente" }, held_on: Date.current + 1)
    end
    assert_response :unprocessable_content
    assert_select "#error_explanation", text: /no puede ser una fecha futura/
  end

  test "solo el profesor de la sección puede marcar asistencia" do
    other_profesor = User.create!(first_name: "Otro", last_name: "Profesor", rut: "66666666-6", email: "otro.profesor@ucv.test",
      role: "profesor", university: universities(:ucv), password: "password123")

    [ users(:ayudante), users(:alumno), other_profesor ].each do |user|
      sign_in user

      get edit_section_attendance_path(@section)
      assert_redirected_to courses_path, "#{user.email} no debería abrir la lista"
      assert_no_difference "AttendanceRecord.count" do
        mark({ users(:alumno).id => "ausente" }, held_on: Date.new(2026, 10, 19))
      end
      assert_equal "presente", attendance_records(:one).reload.status

      sign_out :user
    end
  end

  test "el alumno ve su porcentaje y su detalle por fecha, y nunca la asistencia de otro alumno" do
    classmate = User.create!(first_name: "Compañera", last_name: "Inscrita", rut: "66666666-6", email: "companera@ucv.test",
      role: "alumno", university: universities(:ucv), password: "password123")
    in_ucv do
      Enrollment.create!(section: @section, student: classmate)
      attendance_sessions(:one).attendance_records.create!(student: classmate, status: "ausente")
    end
    sign_in users(:alumno)

    get attendance_path
    assert_select "#my-attendance", text: /ICC1001.*100\s?%/m

    get section_attendance_path(@section)
    assert_response :success
    assert_select "#attendance-percentage", text: /100\s?%/
    assert_select "#attendance-detail li", text: /Presente/, count: 1
    assert_select "#attendance-table", count: 0
    assert_no_match(/Compañera/, response.body)
  end

  test "sin clases registradas se indica en vez de mostrar 0 %" do
    in_ucv { @section.attendance_sessions.destroy_all }
    sign_in users(:alumno)

    get attendance_path
    assert_select "#my-attendance", text: /Aún sin clases/

    get section_attendance_path(@section)
    assert_select "#no-sessions", text: /Aún no hay clases registradas/
    assert_select "#attendance-percentage", count: 0
  end

  test "la asistencia de una sección de otra universidad responde 404" do
    requests = [
      -> { get section_attendance_path(@section) },
      -> { get edit_section_attendance_path(@section) },
      -> { mark({ users(:alumno).id => "ausente" }) }
    ]

    assert_no_difference [ "AttendanceSession.count", "AttendanceRecord.count" ] do
      [ users(:profesor_iusa), users(:alumno_iusa) ].product(requests).each do |user, request|
        # The test sign-in lasts until a response keeps the session, and a 404 does not keep it.
        sign_in user
        request.call
        assert_response :not_found
      end
    end
  end

  test "la asistencia exige iniciar sesión y no está disponible para director ni administrativo" do
    get attendance_path
    assert_redirected_to new_user_session_path

    %i[director administrativo].each do |fixture|
      sign_in users(fixture)

      get attendance_path
      assert_response :redirect
      assert_equal "No tienes permiso para ver esa página.", flash[:alert]
      follow_redirect!
      assert_select "nav a", text: "Asistencia", count: 0

      sign_out :user
    end
  end

  test "el profesor ve en Asistencia las secciones que dicta" do
    sign_in users(:profesor)

    get attendance_path
    assert_select "nav a", text: "Asistencia"
    assert_select "#taught-sections", text: /ICC1001 Programación · Sección 1/
    assert_select "#my-attendance", count: 0
  end
end
