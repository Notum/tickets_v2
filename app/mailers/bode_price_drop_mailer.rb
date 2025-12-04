class BodePriceDropMailer < ApplicationMailer
  def price_dropped(user, price_drops)
    @user = user
    @price_drops = price_drops

    mail(to: @user.email, subject: "Bode.lv Charter Price Drop Alert")
  end
end
