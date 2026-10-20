require "test_helper"

# A11–A14: the administrativo creates, lists, edits and deletes the courses of their university.
class CoursesManagementTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:administrativo) }

  # --- A11 · Crear asignatura ---

  test "el administrativo crea un curso en su universidad" do
    assert_difference -> { course_count }, 1 do
      post courses_path, params: { course: { code: "ICC3003", name: "Redes", faculty_id: faculties(:one).id } }
    end

    course = ActsAsTenant.without_tenant { Course.find_by!(code: "ICC3003") }
    assert_equal universities(:ucv), course.university
    assert_redirected_to course_path(course)
  end

  test "la universidad del curso no se toma del formulario" do
    post courses_path, params: { course: { code: "ICC3003", name: "Redes", faculty_id: faculties(:one).id,
                                           university_id: universities(:iusa).id } }

    assert_equal universities(:ucv), ActsAsTenant.without_tenant { Course.find_by!(code: "ICC3003").university }
  end

  test "rechaza un código repetido en la universidad" do
    assert_no_difference -> { course_count } do
      post courses_path, params: { course: { code: courses(:one).code, name: "Otra", faculty_id: faculties(:one).id } }
    end

    assert_response :unprocessable_content
    assert_select "#error_explanation", text: /Código ya está en uso/
  end

  test "el mismo código puede existir en la otra universidad" do
    assert_difference -> { course_count }, 1 do
      post courses_path, params: { course: { code: courses(:two).code, name: "Anatomía", faculty_id: faculties(:one).id } }
    end
  end

  test "rechaza una facultad de otra universidad" do
    assert_no_difference -> { course_count } do
      post courses_path, params: { course: { code: "ICC3003", name: "Redes", faculty_id: faculties(:two).id } }
    end

    assert_response :unprocessable_content
  end

  test "solo el administrativo puede crear cursos" do
    sign_out :user

    %i[profesor ayudante alumno].each do |fixture|
      sign_in users(fixture)

      assert_no_difference -> { course_count } do
        post courses_path, params: { course: { code: "ICC3003", name: "Redes", faculty_id: faculties(:one).id } }
      end
      assert_redirected_to courses_path

      sign_out :user
    end
  end

  # --- A12 · Ver asignaturas ---

  test "el listado muestra código, nombre, facultad y coordinador del período vigente" do
    ActsAsTenant.with_tenant(universities(:ucv)) { terms(:one).update!(current: true) }

    get courses_path

    assert_response :success
    assert_select "h1", "Cursos"
    assert_select "nav a", text: "Cursos"
    assert_select "#course_#{courses(:one).id}" do
      assert_select "*", text: /ICC1001/
      assert_select "*", text: /Programación/
      assert_select "dd", text: faculties(:one).name
      assert_select "dd", text: users(:profesor).name
      assert_select "a[href=?]", course_path(courses(:one)), text: "Ver"
      assert_select "a[href=?]", course_sections_path(courses(:one)), text: "Secciones"
      assert_select "a[href=?]", edit_course_path(courses(:one)), text: "Editar"
    end
    assert_select "#course_#{courses(:three).id} dd", text: "Sin coordinador"
  end

  test "sin período vigente ningún curso muestra coordinador" do
    get courses_path

    assert_select "#course_#{courses(:one).id} dd", text: "Sin coordinador"
  end

  test "solo aparecen los cursos de la universidad activa" do
    get courses_path

    assert_select "#courses", text: /Programación/
    assert_select "#courses", text: /Bases de Datos/
    assert_select "#courses", text: /Anatomía/, count: 0
  end

  test "sin cursos se muestra un mensaje con acceso a crear el primero" do
    sign_out :user
    university = University.create!(name: "Universidad sin cursos", slug: "sin-cursos")
    admin = User.create!(first_name: "Admin", last_name: "Sin cursos", rut: "66666666-6", email: "admin@sin-cursos.test",
                         password: "password123", role: "administrativo", university: university)
    sign_in admin

    get courses_path

    assert_select "#courses", count: 0
    assert_select "#courses_empty", text: /Todavía no hay cursos en tu universidad/
    assert_select "#courses_empty a[href=?]", new_course_path, text: "Crear el primer curso"
  end

  # --- A13 · Editar asignatura ---

  test "el administrativo edita código, nombre y facultad" do
    patch course_path(courses(:three)), params: { course: { code: "ICC2003", name: "Bases de Datos II" } }

    assert_redirected_to course_path(courses(:three))
    course = ActsAsTenant.without_tenant { courses(:three).reload }
    assert_equal "ICC2003", course.code
    assert_equal "Bases de Datos II", course.name
  end

  test "al editar se valida que el código no se repita" do
    patch course_path(courses(:three)), params: { course: { code: courses(:one).code } }

    assert_response :unprocessable_content
    assert_equal "ICC2002", ActsAsTenant.without_tenant { courses(:three).reload.code }
  end

  test "un curso de otra universidad responde 404" do
    get edit_course_path(courses(:two))
    assert_response :not_found

    patch course_path(courses(:two)), params: { course: { name: "Cambiado" } }
    assert_response :not_found
    assert_equal "Anatomía", ActsAsTenant.without_tenant { courses(:two).reload.name }
  end

  test "solo el administrativo puede editar cursos" do
    sign_out :user
    sign_in users(:profesor)

    patch course_path(courses(:one)), params: { course: { name: "Cambiado" } }

    assert_redirected_to courses_path
    assert_equal "Programación", ActsAsTenant.without_tenant { courses(:one).reload.name }
  end

  # --- A14 · Eliminar asignatura ---

  test "se pide confirmación antes de eliminar" do
    get course_path(courses(:three))

    assert_select "form[action=?][data-turbo-confirm]", course_path(courses(:three))
  end

  test "se elimina un curso sin secciones, coordinadores, materiales ni avisos" do
    assert_difference -> { course_count }, -1 do
      delete course_path(courses(:three))
    end

    assert_redirected_to courses_path
  end

  test "no se elimina un curso con secciones y se muestra el motivo" do
    assert_no_difference -> { course_count } do
      delete course_path(courses(:one))
    end

    assert_redirected_to course_path(courses(:one))
    assert_match "porque tiene secciones", flash[:alert]
  end

  test "no se elimina un curso de otra universidad" do
    assert_no_difference -> { course_count } do
      delete course_path(courses(:two))
    end

    assert_response :not_found
  end

  test "solo el administrativo puede eliminar cursos" do
    sign_out :user
    sign_in users(:profesor)

    assert_no_difference -> { course_count } do
      delete course_path(courses(:three))
    end
    assert_redirected_to courses_path
  end

  private

  def course_count
    ActsAsTenant.without_tenant { Course.count }
  end
end
