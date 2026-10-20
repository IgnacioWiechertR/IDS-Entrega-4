require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  def sign_in_with(email, password)
    post user_session_path, params: { user: { email: email, password: password } }
  end

  test "cada rol llega a su panel al iniciar sesión" do
    {
      director: "/dashboard",
      administrativo: "/accounts",
      profesor: "/courses",
      ayudante: "/courses",
      alumno: "/courses"
    }.each do |fixture, panel|
      sign_in_with users(fixture).email, "password123"
      assert_redirected_to panel, "#{fixture} debería llegar a #{panel}"

      delete destroy_user_session_path
    end
  end

  test "una contraseña incorrecta no inicia sesión" do
    sign_in_with users(:alumno).email, "incorrecta"

    assert_response :unprocessable_content
    assert_select "[role=alert]", "Correo o contraseña inválidos."

    get courses_path
    assert_redirected_to new_user_session_path
  end

  test "la cuenta se bloquea tras 5 intentos fallidos" do
    user = users(:alumno)

    Devise.maximum_attempts.times { sign_in_with user.email, "incorrecta" }
    assert user.reload.access_locked?

    sign_in_with user.email, "password123"
    assert_response :unprocessable_content

    get courses_path
    assert_redirected_to new_user_session_path
  end

  test "las páginas internas exigen iniciar sesión" do
    [ dashboard_path, accounts_path, courses_path ].each do |path|
      get path
      assert_redirected_to new_user_session_path, "#{path} debería exigir sesión"
    end
  end

  test "cerrar sesión vuelve a exigir el login" do
    sign_in users(:profesor)
    get courses_path
    assert_response :success

    delete destroy_user_session_path
    get courses_path
    assert_redirected_to new_user_session_path
  end

  test "la página de login está en español" do
    get new_user_session_path

    assert_response :success
    assert_select "h1", "Iniciar sesión"
    assert_select "label", "Correo"
    assert_select "label", "Contraseña"
  end
end
