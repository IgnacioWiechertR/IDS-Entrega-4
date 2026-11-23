# Rate limiting against password spraying (R8) and request floods (R12).
# Counters live in Rails.cache (memory store in production, null store in test).
class Rack::Attack
  # General limit per IP, excluding the health check and static assets.
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path == "/up" || req.path.start_with?("/assets")
  end

  # Login attempts per IP and per email (Devise route, added in F1).
  throttle("logins/ip", limit: 5, period: 20.seconds) do |req|
    req.ip if req.path == "/users/sign_in" && req.post?
  end

  throttle("logins/email", limit: 5, period: 1.minute) do |req|
    if req.path == "/users/sign_in" && req.post?
      req.params.dig("user", "email").to_s.downcase.strip.presence
    end
  end

  # Password recovery requests (A2): each one sends an email, and Brevo's free plan allows 300 a day.
  throttle("password_resets/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path == "/users/password" && req.post?
  end

  throttle("password_resets/email", limit: 3, period: 15.minutes) do |req|
    if req.path == "/users/password" && req.post?
      req.params.dig("user", "email").to_s.downcase.strip.presence
    end
  end

  self.throttled_responder = lambda do |_req|
    [ 429, { "content-type" => "text/plain; charset=utf-8" }, [ "Demasiadas solicitudes. Intenta nuevamente en unos minutos.\n" ] ]
  end
end

ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _id, payload|
  req = payload[:request]
  Rails.logger.warn("[rack-attack] throttled #{req.env['rack.attack.matched']} ip=#{req.ip} path=#{req.path}")
end
