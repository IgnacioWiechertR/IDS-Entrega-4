class ApplicationMailer < ActionMailer::Base
  # The sender must be verified in Brevo (see the README, "Correo").
  default from: ENV.fetch("MAILER_FROM", "SGA <no-responder@sga.test>")
  layout "mailer"
end
