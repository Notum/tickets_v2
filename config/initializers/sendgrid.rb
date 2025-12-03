require "sendgrid-ruby"

class SendGridDelivery
  def initialize(settings)
    @settings = settings
  end

  def deliver!(mail)
    sendgrid = SendGrid::API.new(api_key: Rails.application.credentials.dig(:sendgrid, :api_key))

    sg_mail = SendGrid::Mail.new
    sg_mail.from = SendGrid::Email.new(email: extract_email(mail.from.first), name: "Tickets@Petrucho.me")
    sg_mail.subject = mail.subject

    personalization = SendGrid::Personalization.new
    mail.to.each do |to_email|
      personalization.add_to(SendGrid::Email.new(email: extract_email(to_email)))
    end
    sg_mail.add_personalization(personalization)

    if mail.text_part
      sg_mail.add_content(SendGrid::Content.new(type: "text/plain", value: mail.text_part.body.to_s))
    end

    if mail.html_part
      sg_mail.add_content(SendGrid::Content.new(type: "text/html", value: mail.html_part.body.to_s))
    elsif mail.body.to_s.present?
      sg_mail.add_content(SendGrid::Content.new(type: "text/plain", value: mail.body.to_s))
    end

    response = sendgrid.client.mail._("send").post(request_body: sg_mail.to_json)

    unless response.status_code.to_i.between?(200, 299)
      Rails.logger.error "[SendGrid] Failed to send email: #{response.status_code} - #{response.body}"
      raise "SendGrid delivery failed: #{response.status_code}"
    end

    Rails.logger.info "[SendGrid] Email sent successfully to #{mail.to.join(', ')}"
    response
  end

  private

  def extract_email(address)
    address.to_s.gsub(/.*<(.+)>.*/, '\1').strip
  end
end

ActionMailer::Base.add_delivery_method :sendgrid, SendGridDelivery
