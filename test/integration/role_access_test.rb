require "test_helper"

class RoleAccessTest < ActionDispatch::IntegrationTest
  test "el director entra al dashboard, a cuentas y a cursos" do
    sign_in users(:director)

    get dashboard_path
    assert_response :success
    get accounts_path
    assert_response :success
    get courses_path
    assert_response :success
    assert_select "h1", "Cursos"
  end

  test "el administrativo entra a cuentas y cursos, pero no al dashboard" do
    sign_in users(:administrativo)

    get accounts_path
    assert_response :success
    get courses_path
    assert_response :success

    get dashboard_path
    assert_redirected_to accounts_path

    get courses_path
    assert_response :success
  end

  test "profesor, ayudante y alumno entran a mis cursos, pero no al dashboard ni a cuentas" do
    %i[profesor ayudante alumno].each do |fixture|
      sign_in users(fixture)

      get courses_path
      assert_response :success, "#{fixture} debería ver Mis cursos"

      get dashboard_path
      assert_redirected_to courses_path, "#{fixture} no debería ver el dashboard"
      get accounts_path
      assert_redirected_to courses_path, "#{fixture} no debería ver cuentas"

      sign_out :user
    end
  end

  test "el menú muestra solo las opciones del rol" do
    sign_in users(:director)
    get dashboard_path
    assert_select "nav a", text: "Dashboard"
    assert_select "nav a", text: "Cuentas"
    assert_select "nav a", text: "Mis cursos", count: 0
    sign_out :user

    sign_in users(:alumno)
    get courses_path
    assert_select "nav a", text: "Mis cursos"
    assert_select "nav a", text: "Dashboard", count: 0
    assert_select "nav a", text: "Cuentas", count: 0
  end

  test "la barra muestra el nombre y el rol de quien inició sesión" do
    sign_in users(:ayudante)
    get courses_path

    assert_select "header", text: /Ayudante UCV · Ayudante/
  end

  test "la portada lleva al panel si ya hay sesión iniciada" do
    sign_in users(:administrativo)
    get root_path

    assert_redirected_to accounts_path
  end
end
