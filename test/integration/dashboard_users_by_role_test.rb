require "test_helper"

# D7: the director sees how many accounts of each role the university picked with the selector has.
class DashboardUsersByRoleTest < ActionDispatch::IntegrationTest
  setup do
    # One extra profesor in UCV, so both universities never have the same counts.
    User.create!(first_name: "Profesora", last_name: "Extra", rut: "10000013-K", email: "extra@ucv.test",
      password: "password123", role: "profesor", university: universities(:ucv))
  end

  def pick(university)
    patch university_selection_path, params: { university_id: university.id }
    follow_redirect!
  end

  def assert_role_counts(university)
    User.count_by_role(university).each do |role, count|
      assert_select "#role-count-#{role} dd", text: count.to_s
    end
    assert_select "#role-count-director", count: 0
  end

  test "el director ve el conteo de usuarios por rol de la universidad seleccionada" do
    sign_in users(:director)
    pick universities(:ucv)

    assert_select "#users-by-role h2", "Usuarios por rol"
    assert_select "#role-count-profesor dt", "Profesor"
    assert_role_counts universities(:ucv)
  end

  test "el conteo cambia al cambiar de universidad con el selector" do
    sign_in users(:director)

    pick universities(:ucv)
    ucv_profesores = css_select("#role-count-profesor dd").text.strip
    assert_role_counts universities(:ucv)

    pick universities(:iusa)
    assert_role_counts universities(:iusa)
    assert_not_equal ucv_profesores, css_select("#role-count-profesor dd").text.strip
  end

  test "es de solo lectura: cada conteo lleva a las cuentas de ese rol" do
    sign_in users(:director)
    pick universities(:ucv)

    assert_select "#users-by-role form", count: 0
    assert_select "#users-by-role input, #users-by-role button", count: 0
    assert_select "#role-count-alumno a[href=?]", accounts_path(role: "alumno")
  end

  test "los demás roles no ven el conteo" do
    %i[administrativo profesor ayudante alumno].each do |fixture|
      sign_in users(fixture)

      get dashboard_path
      assert_response :redirect, "#{fixture} no debería ver el dashboard"
      follow_redirect!
      assert_select "#users-by-role", count: 0

      sign_out :user
    end
  end
end
