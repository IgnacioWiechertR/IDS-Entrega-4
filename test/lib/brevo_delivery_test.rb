require "test_helper"

# Never calls the real API: Net::HTTP.start is replaced while each test runs.
class BrevoDeliveryTest < ActiveSupport::TestCase
  # Runs the block with Net::HTTP.start replaced by the given one (Minitest 6 no longer ships Object#stub).
  def with_http_start(replacement)
    original = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start, &replacement)
    yield
  ensure
    Net::HTTP.define_singleton_method(:start, original)
  end

  # Records the request sent to Brevo and answers it with the given response.
  def stub_brevo(response)
    sent = {}
    fake_http = Object.new
    fake_http.define_singleton_method(:request) { |request| sent[:request] = request; response }

    start = lambda do |host, port, **options, &block|
      sent.merge!(host: host, port: port, options: options)
      block.call(fake_http)
    end

    with_http_start(start) { yield sent }
  end

  def http_response(klass, code, body)
    klass.new("1.1", code, "").tap do |response|
      response.instance_variable_set(:@read, true)
      response.instance_variable_set(:@body, body)
    end
  end

  def multipart_mail
    Mail.new do
      from "SGA <sga.notificaciones@gmail.com>"
      to "Alumno UCV <alumno@ucv.test>"
      cc "copia@ucv.test"
      reply_to "soporte@ucv.test"
      subject "Recupera tu contraseña del SGA"
      text_part { body "Hola en texto" }
      html_part do
        content_type "text/html; charset=UTF-8"
        body "<p>Hola en HTML</p>"
      end
    end
  end

  test "envía el correo a la API de Brevo con la clave y los datos del mensaje" do
    created = http_response(Net::HTTPCreated, "201", '{"messageId":"<1@brevo>"}')

    stub_brevo(created) do |sent|
      result = BrevoDelivery.new(api_key: "clave-de-prueba").deliver!(multipart_mail)
      assert_same created, result

      assert_equal [ "api.brevo.com", 443 ], [ sent[:host], sent[:port] ]
      assert sent[:options][:use_ssl]

      request = sent[:request]
      assert_equal "POST", request.method
      assert_equal "/v3/smtp/email", request.path
      assert_equal "clave-de-prueba", request["api-key"]
      assert_equal "application/json", request["content-type"]

      assert_equal(
        {
          "sender" => { "email" => "sga.notificaciones@gmail.com", "name" => "SGA" },
          "to" => [ { "email" => "alumno@ucv.test", "name" => "Alumno UCV" } ],
          "cc" => [ { "email" => "copia@ucv.test" } ],
          "replyTo" => { "email" => "soporte@ucv.test" },
          "subject" => "Recupera tu contraseña del SGA",
          "htmlContent" => "<p>Hola en HTML</p>",
          "textContent" => "Hola en texto"
        },
        JSON.parse(request.body)
      )
    end
  end

  test "un correo de una sola parte manda solo ese contenido y toma la clave de BREVO_API_KEY" do
    mail = Mail.new(from: "sga@gmail.com", to: "alumno@ucv.test", subject: "Aviso", body: "Solo texto")

    previous = ENV["BREVO_API_KEY"]
    ENV["BREVO_API_KEY"] = "clave-del-entorno"
    stub_brevo(http_response(Net::HTTPCreated, "201", "{}")) do |sent|
      BrevoDelivery.new.deliver!(mail)

      payload = JSON.parse(sent[:request].body)
      assert_equal "clave-del-entorno", sent[:request]["api-key"]
      assert_equal "Solo texto", payload["textContent"]
      assert_not payload.key?("htmlContent")
      assert_not payload.key?("cc")
    end
  ensure
    ENV["BREVO_API_KEY"] = previous
  end

  test "si Brevo responde un error levanta una excepción para que Sidekiq reintente" do
    rejected = http_response(Net::HTTPBadRequest, "400", '{"code":"invalid_parameter","message":"sender is not valid"}')

    stub_brevo(rejected) do
      error = assert_raises(BrevoDelivery::Error) do
        BrevoDelivery.new(api_key: "clave-de-prueba").deliver!(multipart_mail)
      end
      assert_match "Brevo respondió 400", error.message
      assert_match "sender is not valid", error.message
    end
  end

  test "sin clave de API no intenta enviar" do
    previous = ENV.delete("BREVO_API_KEY")

    with_http_start(->(*, **) { flunk "no debería llamar a la API" }) do
      error = assert_raises(BrevoDelivery::Error) { BrevoDelivery.new.deliver!(multipart_mail) }
      assert_equal "Falta BREVO_API_KEY", error.message
    end
  ensure
    ENV["BREVO_API_KEY"] = previous
  end

  test "queda registrado como delivery method :brevo de ActionMailer" do
    assert_equal BrevoDelivery, ActionMailer::Base.delivery_methods[:brevo]
  end
end
