require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "la página de inicio responde en español" do
    get root_path

    assert_response :success
    assert_select "html[lang=es]"
    assert_select "h1", "Sistema de Gestión Académica"
  end

  test "el health check responde" do
    get rails_health_check_path

    assert_response :success
  end
end
