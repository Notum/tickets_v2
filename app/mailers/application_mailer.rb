class ApplicationMailer < ActionMailer::Base
  default from: "Tickets@Petrucho.me <tickets@petrucho.me>",
          reply_to: "noreply@petrucho.me"
  layout "mailer"
end
