require "test_helper"

class DeviseMailerTest < ActionMailer::TestCase
  test "el correo de recuperación va en español con el nombre del SGA y el enlace" do
    user = users(:alumno)
    mail = Devise::Mailer.reset_password_instructions(user, "token-de-prueba")

    assert_equal "Recupera tu contraseña del SGA", mail.subject
    assert_equal [ user.email ], mail.to
    assert_equal [ "no-responder@sga.test" ], mail.from
    assert_equal "SGA", mail[:from].display_names.first

    link = "http://example.com/users/password/edit?reset_password_token=token-de-prueba"
    [ mail.html_part, mail.text_part ].each do |part|
      body = part.decoded
      assert_includes body, "Hola #{user.first_name}"
      assert_includes body, "SGA · Sistema de Gestión Académica"
      assert_includes body, "vence en alrededor de 2 horas"
      assert_includes body, link
    end
  end

  test "la aplicación envía los correos con el mismo remitente" do
    assert_equal "SGA <no-responder@sga.test>", ApplicationMailer.default[:from]
  end
end
