require "test_helper"

# What each role can do in the course and section views (PR #28): the director only reads and sees general
# figures, the coordinator manages the sections of the course they coordinate, the ayudante and the administrativo
# read the attendance without taking it, and a student sees only their own published grades.
class CourseSectionRolesTest < ActionDispatch::IntegrationTest
  DENIED = "No tienes permiso para ver esa página.".freeze

  setup do
    @course = courses(:one)
    @section = sections(:one)
  end

  def in_ucv(&block) = ActsAsTenant.with_tenant(universities(:ucv), &block)

  def sign_in_director
    sign_in users(:director)
    patch university_selection_path, params: { university_id: universities(:ucv).id }
  end

  def section_path(tab: nil) = course_section_path(@course, @section, tab: tab)

  # Director

  test "el director ve cursos y secciones, sin acciones de edición" do
    sign_in_director

    get courses_path
    assert_response :success
    get course_path(@course)
    assert_response :success
    get section_path
    assert_response :success

    assert_select "#section_stats", text: /Promedio/
    [ "Editar sección", "Eliminar sección", "Gestionar alumnos" ].each do |action|
      assert_select "main a, main button", text: action, count: 0
    end
  end

  test "el director no crea, edita ni elimina secciones" do
    sign_in_director

    assert_no_difference -> { in_ucv { Section.count } } do
      post course_sections_path(@course), params: { section: { term_id: terms(:one).id, number: 9 } }
    end
    assert_equal DENIED, flash[:alert]

    patch course_section_path(@course, @section), params: { section: { number: 7 } }
    assert_equal DENIED, flash[:alert]

    delete course_section_path(@course, @section)
    assert_equal DENIED, flash[:alert]

    assert_equal 1, in_ucv { @section.reload.number }
  end

  test "el director ve el promedio de la sección, pero no las notas de cada alumno" do
    sign_in_director

    get section_path(tab: "notas")
    assert_response :success
    assert_select "#section_tabs a", text: "Notas", count: 0
    assert_select "#section_grades", count: 0

    get section_gradebook_path(@section)
    assert_response :not_found
  end

  # Coordinator

  test "el coordinador ve el curso que coordina aunque no dicte, y crea secciones en él" do
    coordinator = User.create!(first_name: "Coordina", last_name: "Bases", rut: "77777777-7", email: "coordina@ucv.test",
      password: "password123", role: "profesor", university: universities(:ucv))
    in_ucv do
      CourseCoordinator.create!(course: courses(:three), term: terms(:one), user: coordinator, assigned_by: users(:administrativo))
    end
    sign_in coordinator

    get courses_path
    assert_select "#course_#{courses(:three).id}_term_#{terms(:one).id}"

    get course_path(courses(:three))
    assert_response :success
    assert_select "#course_info"

    assert_difference -> { in_ucv { courses(:three).sections.count } }, 1 do
      post course_sections_path(courses(:three)), params: { section: { term_id: terms(:one).id, number: 1 } }
    end
  end

  # Ayudante and administrativo

  test "el ayudante ve la tabla de asistencia de su sección, pero no la marca" do
    sign_in users(:ayudante)

    get section_attendance_path(@section)
    assert_response :success
    assert_select "#attendance-table"
    assert_select "a", text: "Marcar asistencia de hoy", count: 0

    get edit_section_attendance_path(@section)
    assert_equal DENIED, flash[:alert]
  end

  test "el administrativo ve la asistencia por alumno, pero no las notas de cada alumno" do
    sign_in users(:administrativo)

    get section_path(tab: "asistencia")
    assert_select "#section_attendance", text: /#{users(:alumno).name}/
    assert_select "#section_tabs a", text: "Notas", count: 0

    # B6: only the profesor of the section takes attendance, even though the administrativo manages sections.
    get edit_section_attendance_path(@section)
    assert_equal DENIED, flash[:alert]
    assert_no_difference -> { AttendanceSession.count } do
      patch section_attendance_path(@section),
            params: { attendance: { held_on: Date.current.iso8601, statuses: { users(:alumno).id => "ausente" } } }
    end
    assert_equal DENIED, flash[:alert]

    get section_gradebook_path(@section)
    assert_response :not_found
  end

  # Student

  test "el alumno ve en la sección solo sus notas publicadas" do
    control2 = Evaluation.create!(section: @section, name: "Control 2", weight: 20, due_on: Date.new(2026, 11, 5))
    Grade.create!(evaluation: control2, student: users(:alumno), score: 6.4, status: "publicada", entered_by: users(:ayudante))
    # grades(:one) is a pending 5.5 of users(:alumno) in evaluations(:one).
    sign_in users(:alumno)

    get section_path(tab: "notas")
    assert_response :success
    assert_select "#my_section_grades", text: /6,4/
    assert_select "#my_section_grades", text: /5,5/, count: 0
    assert_select "#section_tabs", count: 0
    assert_select "#section_attendance", count: 0
  end

  # Deleting a section (A21, stricter: only an empty section is deleted)

  test "una sección con datos no se elimina y se explica el motivo" do
    sign_in users(:administrativo)

    assert_no_difference -> { in_ucv { Section.count } } do
      delete course_section_path(@course, @section)
    end
    assert_redirected_to course_section_path(@course, @section)
    assert_match "No se puede eliminar la sección porque tiene", flash[:alert]
  end

  test "una sección vacía sí se elimina" do
    empty = in_ucv { Section.create!(course: @course, term: terms(:one), number: 5) }
    sign_in users(:administrativo)

    assert_difference -> { in_ucv { Section.count } }, -1 do
      delete course_section_path(@course, empty)
    end
    assert_equal "La sección fue eliminada.", flash[:notice]
  end
end
