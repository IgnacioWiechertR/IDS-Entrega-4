require "test_helper"

# A5: the list of accounts of the active university.
# A4: the administrativo creates one account at a time in their university. The system generates a temporary
# password and shows it only once, on the confirmation page.
class AccountsTest < ActionDispatch::IntegrationTest
  DENIED = "No tienes permiso para ver esa página.".freeze

  def account_params(**attributes)
    { first_name: "Josefa", last_name: "Muñoz", rut: "12.345.678-5", email: "josefa.munoz@ucv.test", role: "alumno" }
      .merge(attributes)
  end

  def create_account(**attributes)
    post accounts_path, params: { account: account_params(**attributes) }
  end

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

  test "el administrativo ve el botón para crear una cuenta; el director no" do
    sign_in users(:administrativo)
    get accounts_path
    assert_select "a[href='#{new_account_path}']", text: "Crear cuenta"

    sign_in users(:director)
    get accounts_path
    assert_select "a[href='#{new_account_path}']", count: 0
  end

  test "el formulario ofrece alumno, ayudante y profesor, con alumno por defecto" do
    sign_in users(:administrativo)

    get new_account_path
    assert_response :success
    assert_select "select#account_role option", count: 3
    assert_select "select#account_role option[selected][value=alumno]"
    %w[administrativo director].each { |role| assert_select "select#account_role option[value=#{role}]", count: 0 }
  end

  test "crea la cuenta en su universidad y muestra la contraseña temporal una sola vez" do
    sign_in users(:administrativo)

    assert_difference -> { User.count }, 1 do
      create_account
    end
    assert_response :created
    assert_includes response.headers["Cache-Control"], "no-store"

    account = User.find_by!(email: "josefa.munoz@ucv.test")
    assert_equal [ universities(:ucv), "alumno", "12345678-5", true ],
                 [ account.university, account.role, account.rut, account.active ]

    password = css_select("#temporary_password").text.strip
    assert_operator password.length, :>=, 12
    assert account.valid_password?(password)
    assert_nil flash[:notice]

    # The new person signs in with the temporary password.
    sign_out :user
    post user_session_path, params: { user: { email: "josefa.munoz@ucv.test", password: password } }
    assert_redirected_to courses_path
  end

  test "crea cuentas de profesor y de ayudante" do
    sign_in users(:administrativo)

    create_account(role: "profesor", rut: "10000001-6", email: "profe.nuevo@ucv.test")
    create_account(role: "ayudante", rut: "10000002-4", email: "ayudante.nuevo@ucv.test")

    assert_equal "profesor", User.find_by!(email: "profe.nuevo@ucv.test").role
    assert_equal "ayudante", User.find_by!(email: "ayudante.nuevo@ucv.test").role
  end

  test "no crea cuentas de administrativo ni de director" do
    sign_in users(:administrativo)

    %w[administrativo director].each do |role|
      assert_no_difference -> { User.count } do
        create_account(role: role)
      end
      assert_equal DENIED, flash[:alert]
    end
  end

  test "la cuenta queda en la universidad del administrativo aunque se envíe otra" do
    sign_in users(:administrativo)

    post accounts_path, params: { account: account_params.merge(university_id: universities(:iusa).id) }

    assert_equal universities(:ucv), User.find_by!(email: "josefa.munoz@ucv.test").university
  end

  test "muestra cada error junto a su campo" do
    sign_in users(:administrativo)

    assert_no_difference -> { User.count } do
      create_account(first_name: "", rut: "12.345.678-9", email: "sin-arroba")
    end
    assert_response :unprocessable_content
    assert_select "#account_first_name_error", text: /Nombre/
    assert_select "#account_rut_error", text: "RUT no es válido, revisa el número y el dígito verificador"
    assert_select "#account_email_error", text: /Correo/
    assert_select "#account_last_name_error", count: 0
    assert_select "input#account_last_name[value=?]", "Muñoz"
  end

  # A8: a repeated RUT in the same university names the account that already has it.
  test "un RUT repetido en la universidad indica la cuenta existente" do
    sign_in users(:administrativo)

    assert_no_difference -> { User.count } do
      create_account(rut: users(:alumno).rut)
    end
    assert_select "#account_rut_error", text: "RUT ya pertenece a la cuenta de Alumno UCV (alumno@ucv.test)"
  end

  test "el mismo RUT se puede usar en la otra universidad" do
    admin_iusa = User.create!(first_name: "Admin", last_name: "IUSA", rut: "22222222-2", email: "admin2@iusa.test",
                              password: "password123", role: "administrativo", university: universities(:iusa))
    sign_in admin_iusa

    assert_difference -> { User.where(university: universities(:iusa)).count }, 1 do
      create_account(rut: users(:ayudante).rut, email: "ayudante.nuevo@iusa.test")
    end
  end

  test "un correo ya usado se rechaza, aunque sea de la otra universidad" do
    sign_in users(:administrativo)

    assert_no_difference -> { User.count } do
      create_account(email: users(:alumno_iusa).email)
    end
    assert_select "#account_email_error"
  end

  test "los demás roles no crean cuentas" do
    %i[director profesor ayudante alumno].each do |fixture|
      sign_in users(fixture)

      get new_account_path
      assert_equal DENIED, flash[:alert], "#{fixture} no debería abrir el formulario"

      assert_no_difference -> { User.count } do
        create_account
      end
      assert_equal DENIED, flash[:alert], "#{fixture} no debería crear cuentas"

      sign_out :user
    end
  end
end
