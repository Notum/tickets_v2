class RyanairPriceDropMailer < ApplicationMailer
  def price_dropped(user, price_drops)
    @user = user
    @price_drops = price_drops

    mail(
      to: @user.email,
      subject: "Ryanair Price Drop Alert"
    )
  end
end
