require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "sin sesión la portada lleva al login" do
    get root_path

    assert_redirected_to new_user_session_path
  end

  test "sin sesión no se muestra información de la app" do
    get root_path
    follow_redirect!

    assert_response :success
    assert_select "html[lang=es]"
    assert_select "h1", "Iniciar sesión"
    University.pluck(:name).each do |name|
      assert_no_match name, response.body
    end
  end

  test "el health check responde" do
    get rails_health_check_path

    assert_response :success
  end
end
