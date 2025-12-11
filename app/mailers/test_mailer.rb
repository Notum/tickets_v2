class TestMailer < ApplicationMailer
  def test_email(recipient)
    @recipient = recipient
    @sent_at = Time.current

    mail(
      to: recipient,
      subject: "Test Email from TicketsV2"
    )
  end
end
