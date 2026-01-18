class SsAdRemovedMailerPreview < ActionMailer::Preview
  def ads_removed
    user = User.first || User.new(email: "test@example.com", price_notification_threshold: 5.0, currency: "EUR")

    removed_ads = [
      {
        title: "3-room flat in Rīga, Centrs",
        ad_type: "flat",
        location: "Brīvības iela 123, Centrs, Rīga",
        rooms: 3,
        area: 78.5,
        floor: "4/5",
        land_area: nil,
        last_price: 115000,
        price_at_follow: 125000,
        url: "https://www.ss.com/msg/lv/real-estate/flats/riga/centre/abcde.html"
      },
      {
        title: "House in Rīga district, Mārupe",
        ad_type: "house",
        location: "Ozolu iela 12, Mārupe, Rīgas rajons",
        rooms: 5,
        area: 180.0,
        floor: nil,
        land_area: 1200,
        last_price: 295000,
        price_at_follow: 320000,
        url: "https://www.ss.com/msg/lv/real-estate/houses/riga-region/marupe/klmno.html"
      }
    ]

    SsAdRemovedMailer.ads_removed(user, removed_ads)
  end
end
