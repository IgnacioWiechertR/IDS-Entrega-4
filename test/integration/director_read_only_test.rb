require "test_helper"

# The director sees everything of the university picked with the selector and changes nothing. The only thing it
# does besides reading is create administrativo accounts, in that university.
class DirectorReadOnlyTest < ActionDispatch::IntegrationTest
  DENIED = "No tienes permiso para ver esa página.".freeze

  setup do
    sign_in users(:director)
    select_university(universities(:ucv))
  end

  def select_university(university)
    patch university_selection_path, params: { university_id: university.id }
  end

  def account_params(**attributes)
    { account: { first_name: "Marta", last_name: "Vidal", rut: "10.000.001-6", email: "marta.vidal@iusa.test",
                 role: "administrativo" }.merge(attributes) }
  end

  # Creating administrativos

  test "crea cuentas de administrativo en la universidad activa" do
    select_university(universities(:iusa))

    get new_account_path
    assert_response :success
    assert_select "p", text: universities(:iusa).name
    assert_select "select#account_role option", count: 1
    assert_select "select#account_role option[value=administrativo]"

    assert_difference -> { User.count }, 1 do
      post accounts_path, params: account_params
    end
    assert_response :created

    account = User.find_by!(email: "marta.vidal@iusa.test")
    assert_equal [ "administrativo", universities(:iusa) ], [ account.role, account.university ]
  end

  test "no crea cuentas de ningún otro rol" do
    %w[alumno ayudante profesor director].each do |role|
      assert_no_difference -> { User.count } do
        post accounts_path, params: account_params(role: role, email: "#{role}.nuevo@ucv.test")
      end
      assert_equal DENIED, flash[:alert], "el director no debería crear cuentas de #{role}"
    end
  end

  test "no importa cuentas desde un CSV" do
    get import_accounts_path
    assert_equal DENIED, flash[:alert]
  end

  # Reading

  test "ve el dashboard, las cuentas, los cursos, los coordinadores y los tres reportes" do
    [ dashboard_path, accounts_path, courses_path, course_coordinators_path, reports_data_completeness_path,
      reports_grade_statuses_path, reports_consolidated_path ].each do |path|
      get path
      assert_response :success, "el director debería ver #{path}"
    end

    get dashboard_path
    %w[Dashboard Cuentas Cursos Coordinadores Anuncios Completitud Notas].each do |item|
      assert_select "nav a", text: item
    end
  end

  test "ve la sección con su asistencia y sus evaluaciones, sin acciones de edición" do
    section = sections(:one)

    get course_section_path(section.course, section)
    assert_response :success
    assert_select "a[href=?]", section_evaluations_path(section), text: "Evaluaciones"
    [ "Marcar asistencia de hoy", "Gestionar alumnos", "Gestionar ayudantes", "Editar sección", "Subir material",
      "Publicar anuncio" ].each { |action| assert_select "a", text: action, count: 0 }

    get section_attendance_path(section)
    assert_response :success

    get section_evaluations_path(section)
    assert_response :success
    assert_select "td, li, h2, h3, p, a", text: /#{evaluations(:one).name}/
    assert_select "a", text: "Nueva evaluación", count: 0
  end

  test "lee los anuncios de la universidad activa y no los de la otra" do
    get announcements_path
    assert_response :success
    assert_select "a[href=?]", announcement_path(announcements(:one)), text: announcements(:one).subject
    assert_select "a[href=?]", announcement_path(announcements(:two)), count: 0

    get announcement_path(announcements(:one))
    assert_response :success

    get announcement_path(announcements(:two))
    assert_response :not_found
  end

  # Changing nothing

  test "no crea ni cambia evaluaciones" do
    section = sections(:one)

    get new_section_evaluation_path(section)
    assert_equal DENIED, flash[:alert]

    assert_no_difference -> { Evaluation.count } do
      post section_evaluations_path(section), params: { evaluation: { name: "Del director", weight: 5, due_on: Date.current } }
    end
    assert_equal DENIED, flash[:alert]
  end

  test "no publica, edita ni elimina anuncios" do
    announcement = announcements(:one)

    assert_no_difference -> { Announcement.count } do
      post announcements_path, params: { announcement: { course_id: announcement.course_id, subject: "Del director", body: "Texto" } }
    end
    assert_equal DENIED, flash[:alert]

    patch announcement_path(announcement), params: { announcement: { subject: "Cambiado" } }
    assert_equal DENIED, flash[:alert]
    assert_equal "Cambio de sala", announcement.reload.subject

    assert_no_difference -> { Announcement.count } do
      delete announcement_path(announcement)
    end
    assert_equal DENIED, flash[:alert]
  end

  test "no cambia roles, datos ni el estado de las cuentas" do
    alumno = users(:alumno)

    patch role_account_path(alumno), params: { account: { role: "ayudante" } }
    assert_equal DENIED, flash[:alert]

    patch account_path(alumno), params: { account: { first_name: "Cambiado" } }
    assert_equal DENIED, flash[:alert]

    delete account_path(alumno)
    assert_equal DENIED, flash[:alert]

    alumno.reload
    assert_equal [ "alumno", "Alumno" ], [ alumno.role, alumno.first_name ]
    assert_not alumno.deactivated?
  end

  test "no asigna coordinadores, profesores, ayudantes ni alumnos" do
    section = sections(:one)

    assert_no_difference -> { CourseCoordinator.count } do
      post course_coordinators_path, params: { course_coordinator: { course_id: section.course_id, term_id: section.term_id,
                                                                    user_id: users(:profesor).id } }
    end
    assert_equal DENIED, flash[:alert]

    assert_no_difference -> { SectionStaff.count } do
      post teacher_assignments_path, params: { section_id: section.id, user_id: users(:profesor).id }
      post course_section_assistant_assignments_path(section.course, section), params: { user_ids: [ users(:alumno).id ] }
    end

    assert_no_difference -> { Enrollment.count } do
      post course_section_enrollments_path(section.course, section), params: { student_ids: [ users(:ayudante).id ] }
    end
  end

  test "no crea, edita ni elimina cursos o secciones, ni toma asistencia" do
    course = courses(:one)
    section = sections(:one)

    assert_no_difference -> { Course.count } do
      post courses_path, params: { course: { code: "DIR101", name: "Del director", faculty_id: course.faculty_id } }
    end
    patch course_path(course), params: { course: { name: "Cambiado" } }
    assert_not_equal "Cambiado", course.reload.name

    assert_no_difference -> { Section.count } do
      delete course_section_path(course, section)
    end

    get edit_section_attendance_path(section)
    assert_equal DENIED, flash[:alert]
  end
end
