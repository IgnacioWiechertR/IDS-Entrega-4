require "test_helper"

class MyCoursesTest < ActionDispatch::IntegrationTest
  test "el profesor ve los cursos donde dicta una sección" do
    sign_in users(:profesor)
    get courses_path

    assert_response :success
    assert_select "#courses", text: /Programación/
    assert_select "#courses", text: /Anatomía/, count: 0
  end

  test "el ayudante ve los cursos donde ayuda" do
    sign_in users(:ayudante)
    get courses_path

    assert_select "#courses", text: /Programación/
  end

  test "cada alumno ve solo los cursos donde está inscrito" do
    sign_in users(:alumno)
    get courses_path
    assert_select "#courses", text: /Programación/
    assert_select "#courses", text: /Anatomía/, count: 0
    sign_out :user

    sign_in users(:alumno_iusa)
    get courses_path
    assert_select "#courses", text: /Anatomía/
    assert_select "#courses", text: /Programación/, count: 0
  end

  test "sin cursos asignados se muestra un mensaje" do
    Enrollment.where(student: users(:alumno)).delete_all
    sign_in users(:alumno)
    get courses_path

    assert_select "#courses", count: 0
    assert_select "p", text: /Todavía no tienes cursos asignados/
  end

  test "el alumno va directo a su sección y no abre un curso donde no participa" do
    sign_in users(:alumno)

    get course_path(courses(:one))
    assert_redirected_to course_section_path(courses(:one), sections(:one))

    get course_path(courses(:three))
    assert_redirected_to courses_path
  end

  test "una inscripción desactivada no da acceso al curso" do
    ActsAsTenant.with_tenant(universities(:ucv)) { enrollments(:one).update!(active: false) }
    sign_in users(:alumno)

    get courses_path
    assert_select "#courses", count: 0
    assert_select "p", text: /Todavía no tienes cursos asignados/

    get course_path(courses(:one))
    assert_redirected_to courses_path
  end

  test "una inscripción nueva queda activa por defecto" do
    assert Enrollment.new.active
  end

  test "el alumno no ve el botón para crear cursos" do
    sign_in users(:alumno)
    get courses_path

    assert_select "h1", "Mis cursos"
    assert_select "a", text: "Nuevo curso", count: 0
  end
end
