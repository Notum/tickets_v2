class AirbalticPriceDropMailer < ApplicationMailer
  def price_dropped(user, price_drops)
    @user = user
    @price_drops = price_drops

    mail(
      to: @user.email,
      subject: "AirBaltic Price Drop Alert"
    )
  end
end
