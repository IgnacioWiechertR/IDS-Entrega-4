require "test_helper"

class AccountsTest < ActionDispatch::IntegrationTest
  test "el administrativo solo ve cuentas de su universidad" do
    sign_in users(:administrativo)

    get accounts_path

    assert_response :success

    within_ucv = %i[administrativo profesor ayudante alumno]

    within_ucv.each do |account|
      assert_select "tbody td", text: users(account).email, count: 1
    end

    %i[profesor_iusa alumno_iusa director].each do |account|
      assert_select "tbody td", text: users(account).email, count: 0
    end
  end
end
