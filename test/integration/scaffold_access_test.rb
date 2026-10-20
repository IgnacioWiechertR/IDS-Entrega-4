require "test_helper"

# The model scaffolds are closed by default: they require signing in, and nobody can use them
# until the card that needs each one adds its rule to the corresponding policy.
class ScaffoldAccessTest < ActionDispatch::IntegrationTest
  SCAFFOLD_PATHS = %w[
    /announcements /attendance_records /attendance_sessions /course_coordinators /enrollments
    /evaluations /faculties /grades /materials /notifications /section_staffs /sections
    /terms /universities /users
  ].freeze

  test "los scaffolds exigen iniciar sesión" do
    (SCAFFOLD_PATHS + [ "/courses/new" ]).each do |path|
      get path
      assert_redirected_to new_user_session_path, "#{path} debería exigir sesión"
    end
  end

  test "con sesión iniciada, los scaffolds se niegan por defecto" do
    %i[director administrativo profesor alumno].each do |fixture|
      sign_in users(fixture)

      SCAFFOLD_PATHS.each do |path|
        get path
        assert_response :redirect, "#{fixture} no debería entrar a #{path}"
        assert_equal "No tienes permiso para ver esa página.", flash[:alert]
      end

      sign_out :user
    end
  end

  test "user_roles ya no tiene ruta" do
    sign_in users(:administrativo)

    get "/user_roles"
    assert_response :not_found
  end

  test "no se puede borrar ni editar a través de un scaffold" do
    sign_in users(:administrativo)

    assert_no_difference "User.count" do
      delete user_path(users(:alumno))
    end
    patch user_path(users(:alumno)), params: { user: { first_name: "Cambiado" } }
    assert_equal "Alumno", users(:alumno).reload.first_name

    assert_no_difference "Course.count" do
      post courses_path, params: { course: { code: "X1", name: "Intrusa" } }
    end
  end
end
