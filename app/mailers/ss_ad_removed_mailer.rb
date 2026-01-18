class SsAdRemovedMailer < ApplicationMailer
  def ads_removed(user, ads)
    @user = user
    @ads = ads

    mail(
      to: @user.email,
      subject: "SS.COM - Followed Ads Removed"
    )
  end
end
