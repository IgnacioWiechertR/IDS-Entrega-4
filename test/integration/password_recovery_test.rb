require "test_helper"

# A2 (CU 1-2): the user recovers a forgotten password with a link sent to their email.
class PasswordRecoveryTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  PARANOID_NOTICE = "Si el correo pertenece a una cuenta, en unos minutos recibirás un enlace para crear una contraseña nueva.".freeze

  setup { @user = users(:alumno) }

  def request_reset(email)
    post user_password_path, params: { user: { email: email } }
  end

  # Sends the email through the Sidekiq job and returns the link it carries.
  def reset_link_for(email)
    perform_enqueued_jobs { request_reset(email) }
    ActionMailer::Base.deliveries.last.text_part.decoded[%r{http://\S+}]
  end

  def change_password(token, password, confirmation = password)
    put user_password_path, params: {
      user: { reset_password_token: token, password: password, password_confirmation: confirmation }
    }
  end

  test "el login enlaza a la recuperación de contraseña" do
    get new_user_session_path

    assert_select "a[href=?]", new_user_password_path, "¿Olvidaste tu contraseña?"
  end

  test "pedir el enlace encola el correo en Sidekiq y no revela nada" do
    get new_user_password_path
    assert_response :success
    assert_select "h1", "¿Olvidaste tu contraseña?"

    assert_enqueued_email_with Devise::Mailer, :reset_password_instructions, args: ->(args) { args.first == @user } do
      request_reset(@user.email)
    end

    assert_redirected_to new_user_session_path
    follow_redirect!
    assert_select "[role=status]", PARANOID_NOTICE
    assert_not_nil @user.reload.reset_password_sent_at
  end

  test "un correo sin cuenta recibe la misma respuesta y no envía nada" do
    assert_no_enqueued_emails do
      request_reset("nadie@ucv.test")
    end

    assert_redirected_to new_user_session_path
    follow_redirect!
    assert_select "[role=status]", PARANOID_NOTICE
  end

  test "una cuenta desactivada no recibe el correo" do
    @user.update!(active: false)

    assert_no_enqueued_emails { request_reset(@user.email) }
    assert_redirected_to new_user_session_path
  end

  test "con el enlace del correo se cambia la contraseña y se inicia sesión" do
    link = reset_link_for(@user.email.upcase)
    assert link.start_with?("http://example.com/users/password/edit?reset_password_token=")

    get link
    assert_response :success
    assert_select "h1", "Crea una contraseña nueva"
    token = link[/reset_password_token=(\S+)/, 1]

    change_password(token, "nueva-clave-segura")
    assert_redirected_to "/courses"
    follow_redirect!
    assert_select "[role=status]", "Tu contraseña fue cambiada. Ya iniciaste sesión."

    assert @user.reload.valid_password?("nueva-clave-segura")
    assert_nil @user.reset_password_token

    # The link works only once.
    delete destroy_user_session_path
    change_password(token, "otra-clave-segura")
    assert_response :unprocessable_content
    assert_select "[role=alert]", /El enlace no es válido o ya expiró/
  end

  test "un token inválido no cambia la contraseña" do
    change_password("token-inventado", "nueva-clave-segura")

    assert_response :unprocessable_content
    assert_select "[role=alert]", /El enlace no es válido o ya expiró/
    assert @user.reload.valid_password?("password123")
  end

  test "un enlace de más de 2 horas expiró" do
    token = reset_link_for(@user.email)[/reset_password_token=(\S+)/, 1]

    travel 2.hours + 1.minute do
      change_password(token, "nueva-clave-segura")
    end

    assert_response :unprocessable_content
    assert_select "[role=alert]", /El enlace no es válido o ya expiró/
    assert @user.reload.valid_password?("password123")
  end

  test "la contraseña nueva debe cumplir las reglas" do
    token = reset_link_for(@user.email)[/reset_password_token=(\S+)/, 1]

    change_password(token, "corta")
    assert_response :unprocessable_content
    assert_select "#user_password_error", /demasiado corto/

    change_password(token, "nueva-clave-segura", "distinta-clave-segura")
    assert_response :unprocessable_content
    assert_select "#user_password_confirmation_error", /no coincide/

    assert @user.reload.valid_password?("password123")
  end

  test "abrir el formulario sin token vuelve al login" do
    get edit_user_password_path

    assert_redirected_to new_user_session_path
    follow_redirect!
    assert_select "[role=alert]", "Para cambiar tu contraseña abre el enlace del correo de recuperación completo."
  end

  test "recuperar la contraseña desbloquea una cuenta bloqueada" do
    Devise.maximum_attempts.times do
      post user_session_path, params: { user: { email: @user.email, password: "incorrecta" } }
    end
    assert @user.reload.access_locked?

    token = reset_link_for(@user.email)[/reset_password_token=(\S+)/, 1]
    change_password(token, "nueva-clave-segura")

    assert_redirected_to "/courses"
    @user.reload
    assert_not @user.access_locked?
    assert_equal 0, @user.failed_attempts

    delete destroy_user_session_path
    post user_session_path, params: { user: { email: @user.email, password: "nueva-clave-segura" } }
    assert_redirected_to "/courses"
  end

  test "con sesión iniciada no se puede pedir otro enlace" do
    sign_in @user

    get new_user_password_path
    assert_redirected_to "/courses"
  end
end
