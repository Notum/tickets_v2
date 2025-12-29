class FetchFailureMailer < ApplicationMailer
  ADMIN_EMAIL = "pjotrs.sokolovs@gmail.com".freeze

  def fetch_failed(airline:, failures:)
    @airline = airline
    @failures = failures
    @timestamp = Time.current

    mail(
      to: ADMIN_EMAIL,
      subject: "[Alert] #{airline} Fetch Failures - #{failures.count} error(s)"
    )
  end
end
