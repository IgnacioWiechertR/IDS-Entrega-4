# A2: delivery method :brevo (Brevo's HTTP API), used in production. See lib/brevo_delivery.rb.
require Rails.root.join("lib/brevo_delivery").to_s

ActiveSupport.on_load(:action_mailer) do
  add_delivery_method :brevo, BrevoDelivery
end
