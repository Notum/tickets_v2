class UserMailer < ApplicationMailer
  def welcome_email(user)
    @user = user
    @login_url = login_url

    mail(
      to: @user.email,
      subject: "Welcome to TicketsV2 - Your Account Has Been Created"
    )
  end
end
