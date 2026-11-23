require "json"
require "net/http"

# ActionMailer delivery method that sends through Brevo's transactional email API over HTTPS. Render's free plan
# blocks outgoing SMTP ports, so SMTP is not an option in production (see docs/decisiones.md).
#
#   config.action_mailer.delivery_method = :brevo
#
# Any failure raises, so the Sidekiq job of deliver_later retries the email.
class BrevoDelivery
  class Error < StandardError; end

  ENDPOINT = URI("https://api.brevo.com/v3/smtp/email").freeze

  attr_accessor :settings

  def initialize(settings = {})
    @settings = settings
  end

  def deliver!(mail)
    response = post(payload(mail))
    return response if response.is_a?(Net::HTTPSuccess)

    raise Error, "Brevo respondió #{response.code}: #{response.body}"
  end

  private

  def api_key
    settings[:api_key].presence || ENV["BREVO_API_KEY"].presence || raise(Error, "Falta BREVO_API_KEY")
  end

  def post(body)
    request = Net::HTTP::Post.new(ENDPOINT)
    request["api-key"] = api_key
    request["accept"] = "application/json"
    request["content-type"] = "application/json"
    request.body = body.to_json

    Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, open_timeout: 5, read_timeout: 15) do |http|
      http.request(request)
    end
  end

  def payload(mail)
    {
      sender: contacts(mail[:from]).first,
      to: contacts(mail[:to]),
      cc: contacts(mail[:cc]).presence,
      bcc: contacts(mail[:bcc]).presence,
      replyTo: contacts(mail[:reply_to]).first,
      subject: mail.subject,
      htmlContent: content(mail, "text/html"),
      textContent: content(mail, "text/plain")
    }.compact
  end

  # Brevo takes each address as { email:, name: }, with the name only when the header has one.
  def contacts(field)
    return [] if field.nil?

    field.addrs.map { |address| { email: address.address, name: address.display_name }.compact }
  end

  # A single-part message without a content type is plain text, as in the email RFCs.
  def content(mail, mime_type)
    return mail.all_parts.find { |part| part.mime_type == mime_type }&.decoded if mail.multipart?

    mail.decoded if (mail.mime_type || "text/plain") == mime_type
  end
end
