require "test_helper"

# Editing and deleting accounts. The administrativo edits and deletes the alumnos, ayudantes and profesores of its
# university. The director only reads them.
#
# Deleting an account (card "Eliminar cuenta"):
# 1. deactivates it: the person can no longer sign in;
# 2. never removes the row, so its grades and attendance keep their history;
# 3. asks for confirmation first;
# 4. only reaches accounts of the administrativo's own university.
class AccountManagementTest < ActionDispatch::IntegrationTest
  DENIED = "No tienes permiso para ver esa página.".freeze

  def new_account(**attributes)
    User.create!({
      first_name: "Josefa", last_name: "Muñoz", rut: "12.345.678-5", email: "josefa.munoz@ucv.test",
      role: "alumno", university: universities(:ucv), password: "password123", active: true
    }.merge(attributes))
  end

  def select_university(university)
    patch university_selection_path, params: { university_id: university.id }
  end

  # Editing

  test "el administrativo edita los datos de una cuenta de su universidad" do
    account = new_account
    sign_in users(:administrativo)

    get edit_account_path(account)
    assert_response :success
    assert_select "input#account_rut[value=?]", "12345678-5"

    patch account_path(account), params: {
      account: { first_name: "Josefina", last_name: "Muñoz Rojas", rut: "10.000.001-6", email: "josefina@ucv.test" }
    }

    assert_redirected_to accounts_path
    assert_equal "Datos de Josefina Muñoz Rojas actualizados.", flash[:notice]
    assert_equal [ "Josefina", "Muñoz Rojas", "10000001-6", "josefina@ucv.test" ],
                 account.reload.slice(:first_name, :last_name, :rut, :email).values
  end

  test "editar no cambia el rol, la universidad, el estado ni la contraseña" do
    account = new_account
    sign_in users(:administrativo)

    patch account_path(account), params: {
      account: { first_name: "Otra", role: "profesor", university_id: universities(:iusa).id, active: false,
                 password: "otra-clave-123" }
    }

    account.reload
    assert_equal "Otra", account.first_name
    assert_equal [ "alumno", universities(:ucv), true ], [ account.role, account.university, account.active ]
    assert account.valid_password?("password123")
  end

  test "muestra los errores junto a su campo y conserva lo escrito" do
    account = new_account
    sign_in users(:administrativo)

    patch account_path(account), params: { account: { first_name: "", rut: users(:alumno).rut, email: "sin-arroba" } }

    assert_response :unprocessable_content
    assert_select "#account_first_name_error", text: /Nombre/
    assert_select "#account_rut_error", text: "RUT ya pertenece a la cuenta de Alumno UCV (alumno@ucv.test)"
    assert_select "#account_email_error", text: /Correo/
    assert_equal "Josefa", account.reload.first_name
  end

  test "conserva la búsqueda, el filtro y la página al volver al listado" do
    account = new_account
    sign_in users(:administrativo)

    patch account_path(account, q: "Muñoz", role: "alumno", page: 1), params: { account: { first_name: "Jo" } }

    assert_redirected_to accounts_path(q: "Muñoz", role: "alumno", page: 1)
  end

  test "el listado ofrece editar solo las cuentas que se pueden gestionar" do
    sign_in users(:administrativo)
    get accounts_path

    %i[profesor ayudante alumno].each do |fixture|
      assert_select "a[href^='#{edit_account_path(users(fixture))}']", text: "Editar"
    end
    assert_select "a[href^='#{edit_account_path(users(:administrativo))}']", count: 0
  end

  test "el administrativo no edita administrativos, al director ni cuentas de la otra universidad" do
    sign_in users(:administrativo)

    patch account_path(users(:administrativo)), params: { account: { first_name: "Cambiado" } }
    assert_equal DENIED, flash[:alert]

    # The director and the accounts of IUSA are not in the active university: they are not found.
    [ users(:director), users(:alumno_iusa) ].each do |account|
      patch account_path(account), params: { account: { first_name: "Cambiado" } }
      assert_response :not_found
      assert_not_equal "Cambiado", account.reload.first_name
    end
  end

  test "profesor, ayudante y alumno no editan cuentas" do
    account = new_account

    %i[profesor ayudante alumno].each do |fixture|
      sign_in users(fixture)

      get edit_account_path(account)
      assert_equal DENIED, flash[:alert]

      patch account_path(account), params: { account: { first_name: "Cambiado" } }
      assert_equal "Josefa", account.reload.first_name

      sign_out :user
    end
  end

  # The director only reads accounts and creates administrativos (DirectorReadOnlyTest).
  test "el director no edita cuentas" do
    account = new_account
    sign_in users(:director)
    patch university_selection_path, params: { university_id: universities(:ucv).id }

    get accounts_path
    assert_select "a", text: "Editar", count: 0
    assert_select "a", text: "Mi cuenta", count: 0

    get edit_account_path(account)
    assert_equal DENIED, flash[:alert]

    patch account_path(account), params: { account: { first_name: "Cambiado" } }
    assert_equal DENIED, flash[:alert]
    assert_equal "Josefa", account.reload.first_name

    # The director has no university, so its own account is not among the accounts of the active one.
    patch account_path(users(:director)), params: { account: { first_name: "Cambiado" } }
    assert_response :not_found
    assert_equal "Directora", users(:director).reload.first_name
  end

  # Deleting (card "Eliminar cuenta")

  # Criterion 1: deleting deactivates the account and the person can no longer sign in.
  test "eliminar desactiva la cuenta y la persona ya no puede iniciar sesión" do
    account = new_account
    sign_in users(:administrativo)

    delete account_path(account)

    assert_redirected_to accounts_path
    assert_equal "La cuenta de Josefa Muñoz fue eliminada: ya no puede iniciar sesión. Su historial se conserva.",
                 flash[:notice]
    assert account.reload.deactivated?

    get accounts_path
    assert_select "tbody td", text: "Eliminada"

    sign_out :user
    post user_session_path, params: { user: { email: account.email, password: "password123" } }
    follow_redirect! if response.redirect?
    assert_select "[role=alert]", text: "Tu cuenta está desactivada. Contacta a la administración de tu universidad."
    get courses_path
    assert_redirected_to new_user_session_path
  end

  test "eliminar cierra la sesión que la persona tenía abierta" do
    alumno = users(:alumno)
    sign_in alumno
    get courses_path
    assert_response :success

    # The administrativo deletes it from its own session: only the database changes. On the next request Devise
    # loads the account again from the database and signs it out.
    alumno.update_columns(active: false)

    get courses_path
    assert_redirected_to new_user_session_path
  end

  # Criterion 2: an account with grades stays in the database, and so do its grades.
  test "una cuenta con notas no se borra de la base de datos y conserva su historial" do
    alumno = users(:alumno)
    ayudante = users(:ayudante)
    sign_in users(:administrativo)

    assert_no_difference [ -> { User.count }, -> { ActsAsTenant.without_tenant { Grade.count } },
                           -> { ActsAsTenant.without_tenant { Enrollment.count } },
                           -> { ActsAsTenant.without_tenant { SectionStaff.count } } ] do
      delete account_path(alumno)
      delete account_path(ayudante)
    end

    assert alumno.reload.deactivated?
    assert ayudante.reload.deactivated?
    assert ActsAsTenant.without_tenant { Grade.exists?(student: alumno) }
    assert ActsAsTenant.without_tenant { Grade.exists?(entered_by: ayudante) }
  end

  test "una cuenta sin historial tampoco se borra: también se desactiva" do
    account = new_account
    sign_in users(:administrativo)

    assert_no_difference -> { User.count } do
      delete account_path(account)
    end
    assert account.reload.deactivated?
  end

  # Criterion 3: the delete buttons ask for confirmation before sending the request.
  test "pide confirmación antes de eliminar, en el listado y en la edición" do
    account = new_account
    sign_in users(:administrativo)

    get accounts_path
    assert_select "form[action^='#{account_path(account)}'][data-turbo-confirm*='Josefa Muñoz']" do
      assert_select "input[name=_method][value=delete]"
      assert_select "button", text: "Eliminar"
    end

    get edit_account_path(account)
    assert_select "#account_danger_zone form[data-turbo-confirm*='Ya no podrá iniciar sesión']", count: 1
  end

  # Criterion 4: only accounts of the administrativo's own university.
  test "no elimina cuentas de la otra universidad aunque se envíe su id" do
    sign_in users(:administrativo)

    delete account_path(users(:alumno_iusa))

    assert_response :not_found
    assert_not users(:alumno_iusa).reload.deactivated?
  end

  test "el administrativo de IUSA elimina en su universidad y no en UCV" do
    sign_in users(:administrativo_iusa)

    delete account_path(users(:alumno_iusa))
    assert users(:alumno_iusa).reload.deactivated?

    delete account_path(users(:alumno))
    assert_response :not_found
    assert_not users(:alumno).reload.deactivated?
  end

  test "el administrativo no elimina administrativos, al director ni su propia cuenta" do
    sign_in users(:administrativo)

    delete account_path(users(:administrativo))
    assert_equal DENIED, flash[:alert]
    assert_not users(:administrativo).reload.deactivated?

    delete account_path(users(:director))
    assert_response :not_found
    assert_not users(:director).reload.deactivated?
  end

  test "director, profesor, ayudante y alumno no eliminan cuentas" do
    account = new_account

    %i[director profesor ayudante alumno].each do |fixture|
      sign_in users(fixture)
      patch university_selection_path, params: { university_id: universities(:ucv).id } if fixture == :director

      delete account_path(account)
      assert_equal DENIED, flash[:alert], "#{fixture} no debería eliminar cuentas"

      sign_out :user
    end
    assert_not account.reload.deactivated?
  end

  test "eliminar dos veces no cambia nada y lo avisa" do
    account = new_account(active: false)
    sign_in users(:administrativo)

    delete account_path(account)

    assert_equal "La cuenta de Josefa Muñoz ya estaba eliminada.", flash[:notice]
    assert account.reload.deactivated?
  end

  # Undoing a deletion by mistake.
  test "reactivar devuelve el acceso" do
    account = new_account(active: false)
    sign_in users(:administrativo)

    get accounts_path
    assert_select "button", text: "Reactivar"

    patch reactivate_account_path(account)
    assert_redirected_to accounts_path
    assert_not account.reload.deactivated?

    sign_out :user
    post user_session_path, params: { user: { email: account.email, password: "password123" } }
    assert_redirected_to courses_path
  end

  test "solo el administrativo de la universidad reactiva cuentas" do
    account = new_account(active: false)

    %i[director profesor alumno administrativo_iusa].each do |fixture|
      sign_in users(fixture)
      patch reactivate_account_path(account)
      sign_out :user
    end

    assert account.reload.deactivated?
  end
end
