require "test_helper"

class UniversityIsolationTest < ActionDispatch::IntegrationTest
  test "un recurso de otra universidad responde 404 aunque se pida por URL" do
    sign_in users(:profesor)

    get course_path(courses(:two))
    assert_response :not_found
  end

  test "cada usuario ve el nombre de su universidad en la barra" do
    sign_in users(:alumno_iusa)
    get courses_path

    assert_select "header", text: /Instituto Universitario de Salud Austral/
    assert_select "header", text: /Universidad Central del Valle/, count: 0
  end

  test "una persona con cuenta en ambas universidades ve datos distintos según la cuenta" do
    assert_equal users(:profesor).rut, users(:profesor_iusa).rut

    sign_in users(:profesor)
    get courses_path
    assert_select "#courses", text: /Programación/
    assert_select "#courses", text: /Anatomía/, count: 0
    sign_out :user

    sign_in users(:profesor_iusa)
    get courses_path
    assert_select "#courses", text: /Anatomía/
    assert_select "#courses", text: /Programación/, count: 0
  end

  test "el director elige la universidad activa con el selector" do
    sign_in users(:director)

    patch university_selection_path, params: { university_id: universities(:iusa).id }
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_select "#active-university", text: /Instituto Universitario de Salud Austral/
    assert_select "header select option[selected]", text: "Instituto Universitario de Salud Austral"

    patch university_selection_path, params: { university_id: universities(:ucv).id }
    follow_redirect!
    assert_select "#active-university", text: /Universidad Central del Valle/
  end

  test "solo el director puede cambiar de universidad" do
    sign_in users(:administrativo)

    patch university_selection_path, params: { university_id: universities(:iusa).id }
    assert_redirected_to accounts_path
    assert_equal "No tienes permiso para ver esa página.", flash[:alert]

    get accounts_path
    assert_select "header", text: /Universidad Central del Valle/
    assert_select "header select", count: 0
  end

  test "sin universidad activa, las consultas fallan en vez de mezclar universidades" do
    assert_raises(ActsAsTenant::Errors::NoTenantSet) { Course.count }

    ActsAsTenant.with_tenant(universities(:ucv)) do
      assert_equal %w[ICC1001 ICC2002], Course.order(:code).pluck(:code)
    end
  end
end
