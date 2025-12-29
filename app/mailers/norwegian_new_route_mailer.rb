class NorwegianNewRouteMailer < ApplicationMailer
  def new_routes_available(user, new_routes)
    @user = user
    @new_routes = new_routes

    mail(
      to: @user.email,
      subject: "New Norwegian Routes from Riga"
    )
  end
end
