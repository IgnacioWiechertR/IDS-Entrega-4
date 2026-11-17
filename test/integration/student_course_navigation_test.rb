require "test_helper"

# C15 and B18: inside their section the student has tabs (Resumen · Notas · Asistencia) and never needs to leave the
# course to see their grades or attendance; the general "Mis notas" and "Asistencia" stay and link to each course.
class StudentCourseNavigationTest < ActionDispatch::IntegrationTest
  setup do
    @course = courses(:one)
    @section = sections(:one)
    # grades(:one) is a pending 5.5 of users(:alumno) in evaluations(:one) ("Control 1").
    @evaluation = Evaluation.create!(section: @section, name: "Control 2", weight: 20, due_on: Date.new(2026, 11, 5))
    @published = Grade.create!(evaluation: @evaluation, student: users(:alumno), score: 6.4, status: "publicada",
                               entered_by: users(:ayudante), reviewed_by: users(:profesor))
  end

  def section_path(tab: nil) = course_section_path(@course, @section, tab: tab)

  # CA1
  test "el alumno ve las pestañas Resumen, Notas y Asistencia, con la activa marcada" do
    sign_in users(:alumno)

    get section_path
    assert_select "#student_tabs a", count: 3
    assert_select "#student_tabs a[aria-current=page]", text: "Resumen"
    assert_select "#student_tabs a[href=?]", section_path(tab: "notas"), text: "Notas"
    assert_select "#student_tabs a[href=?]", section_path(tab: "asistencia"), text: "Asistencia"

    get section_path(tab: "notas")
    assert_select "#student_tabs a[aria-current=page]", text: "Notas"
    assert_select "#section_tabs", count: 0
  end

  test "una pestaña desconocida cae en Resumen" do
    sign_in users(:alumno)

    get section_path(tab: "inventada")
    assert_response :success
    assert_select "#student_tabs a[aria-current=page]", text: "Resumen"
  end

  # CA2
  test "Resumen muestra su promedio, su asistencia y el material, sin la tabla de notas" do
    sign_in users(:alumno)
    get section_path

    assert_select "#my_stats", text: /Mi promedio.*6,4.*Mi asistencia/m
    assert_select "#materials"
    assert_select "#my_section_grades", count: 0
  end

  # CA3
  test "Notas muestra cada evaluación; solo las publicadas tienen nota y enlace al detalle" do
    sign_in users(:alumno)
    get section_path(tab: "notas")

    assert_select "#my_section_grades tr", text: /Control 2.*20 %.*6,4/m
    assert_select "#my_section_grades a[href=?]", my_grade_path(@published), text: "6,4"
    # The pending grade of Control 1 is shown as "—", without its score or a link.
    assert_select "#my_section_grades tr", text: /Control 1.*—/m
    assert_select "#my_section_grades", text: /5,5/, count: 0
    assert_select "#my_section_grades a", count: 1
    assert_select "#my_section_average", text: /6,4/
    assert_select "a[href=?]", my_grades_path, text: "Ver todas mis notas"
    assert_select "#materials", count: 0
  end

  test "Notas sin evaluaciones muestra un mensaje" do
    # A student has one role per course and term, so the empty section gets a student of its own.
    student = User.create!(first_name: "Compañera", last_name: "Curso", rut: "10000005-9", email: "companera@ucv.test",
      password: "password123", role: "alumno", university: universities(:ucv))
    empty = ActsAsTenant.with_tenant(universities(:ucv)) do
      section = Section.create!(course: @course, term: terms(:one), number: 7)
      Enrollment.create!(section: section, student: student)
      section
    end
    sign_in student
    get course_section_path(@course, empty, tab: "notas")

    assert_select "#no_section_evaluations", text: /Esta sección aún no tiene evaluaciones/
    assert_select "#my_section_grades", count: 0
  end

  # CA4
  test "el detalle de entrega vuelve a la pestaña Notas del curso y ofrece ver todas mis notas" do
    sign_in users(:alumno)
    get my_grade_path(@published)

    assert_select "a[href=?]", section_path(tab: "notas"), text: "← ICC1001 Programación · Sección 1"
    assert_select "a[href=?]", my_grades_path, text: "Ver todas mis notas"
  end

  test "con la matrícula inactiva el detalle de entrega no enlaza a la sección" do
    ActsAsTenant.with_tenant(universities(:ucv)) { enrollments(:one).update!(active: false) }
    sign_in users(:alumno)
    get my_grade_path(@published)

    assert_response :success
    assert_select "a[href=?]", section_path(tab: "notas"), count: 0
    assert_select "a[href=?]", my_grades_path, text: "← Mis notas"
  end

  # CA5
  test "en Mis notas el encabezado de cada asignatura enlaza a su pestaña Notas" do
    sign_in users(:alumno)
    get my_grades_path

    assert_select "#section_#{@section.id} header a[href=?]", section_path(tab: "notas"), text: /ICC1001.*Programación/
  end

  # B18 CA1
  test "Asistencia muestra su porcentaje, cuántas clases asistió y el detalle por clase, solo suyo" do
    classmate = User.create!(first_name: "Compañera", last_name: "Inscrita", rut: "66666666-6", email: "companera@ucv.test",
      role: "alumno", university: universities(:ucv), password: "password123")
    ActsAsTenant.with_tenant(universities(:ucv)) do
      Enrollment.create!(section: @section, student: classmate)
      attendance_sessions(:one).attendance_records.create!(student: classmate, status: "ausente")
    end
    sign_in users(:alumno)
    get section_path(tab: "asistencia")

    assert_select "#student_tabs a[aria-current=page]", text: "Asistencia"
    assert_select "#attendance-percentage", text: /100\s?%/
    assert_select "p", text: /Asististe a 1 de 1 clases registradas/
    assert_select "#attendance-detail li", text: /Presente/, count: 1
    assert_select "#attendance-detail li", text: /Ausente/, count: 0
    assert_select "#section_attendance", count: 0
    assert_select "#materials", count: 0
    assert_no_match(/Compañera/, response.body)
  end

  test "Asistencia sin clases registradas muestra un mensaje" do
    ActsAsTenant.with_tenant(universities(:ucv)) { @section.attendance_sessions.destroy_all }
    sign_in users(:alumno)
    get section_path(tab: "asistencia")

    assert_select "#no-sessions", text: /Aún no hay clases registradas/
    assert_select "#attendance-percentage", count: 0
  end

  # B18 CA2
  test "Resumen enlaza a la pestaña Asistencia" do
    sign_in users(:alumno)
    get section_path

    assert_select "a[href=?]", section_path(tab: "asistencia"), text: "Detalle de mi asistencia"
    assert_select "a[href=?]", section_attendance_path(@section), count: 0
  end

  # B18 CA3
  test "el enlace antiguo al detalle de asistencia lleva al alumno a la pestaña, y el profesor sigue viendo su tabla" do
    sign_in users(:alumno)
    get section_attendance_path(@section)
    assert_redirected_to section_path(tab: "asistencia")
    sign_out :user

    sign_in users(:profesor)
    get section_attendance_path(@section)
    assert_response :success
    assert_select "#attendance-table"
  end

  # B18 CA4
  test "en Asistencia (general) cada asignatura del alumno enlaza a su pestaña" do
    sign_in users(:alumno)
    get attendance_path

    assert_select "#my-attendance a[href=?]", section_path(tab: "asistencia"), text: /ICC1001/
  end

  # B18 CA-AUT
  test "con la matrícula inactiva el alumno no ve la asistencia de la sección" do
    ActsAsTenant.with_tenant(universities(:ucv)) { enrollments(:one).update!(active: false) }
    sign_in users(:alumno)

    get section_attendance_path(@section)
    assert_response :redirect
    assert_equal "No tienes permiso para ver esa página.", flash[:alert]

    get section_path(tab: "asistencia")
    assert_response :redirect
    assert_equal "No tienes permiso para ver esa página.", flash[:alert]
  end

  # CA-AUT
  test "la vista del profesor no cambia: sin pestañas de alumno y con sus propias pestañas" do
    sign_in users(:profesor)
    get section_path(tab: "notas")

    assert_response :success
    assert_select "#student_tabs", count: 0
    assert_select "#section_tabs a[aria-current=page]", text: "Notas"
    assert_select "#section_grades"
    assert_select "#materials"
  end
end
