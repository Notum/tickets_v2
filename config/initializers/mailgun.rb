require "mailgun-ruby"

# Custom ActionMailer delivery method for Mailgun
# Credentials are expected in rails credentials:
#   mailgun:
#     api_key: your_api_key
#     domain: your_domain.mailgun.org

class MailgunDelivery
  def initialize(settings)
    @settings = settings
  end

  def deliver!(mail)
    api_key = Rails.application.credentials.dig(:mailgun, :api_key)
    domain = Rails.application.credentials.dig(:mailgun, :domain)

    client = Mailgun::Client.new(api_key, "api.eu.mailgun.net")

    message_params = {
      from: mail.from.first,
      to: mail.to.join(", "),
      subject: mail.subject
    }

    if mail.text_part
      message_params[:text] = mail.text_part.body.to_s
    end

    if mail.html_part
      message_params[:html] = mail.html_part.body.to_s
    elsif mail.body.to_s.present? && !mail.text_part
      message_params[:text] = mail.body.to_s
    end

    response = client.send_message(domain, message_params)

    Rails.logger.info "[Mailgun] Email sent successfully to #{mail.to.join(', ')}"
    response
  rescue Mailgun::CommunicationError => e
    Rails.logger.error "[Mailgun] Failed to send email: #{e.message}"
    raise "Mailgun delivery failed: #{e.message}"
  end
end

ActionMailer::Base.add_delivery_method :mailgun, MailgunDelivery
