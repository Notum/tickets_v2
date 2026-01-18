class SsPriceDropMailerPreview < ActionMailer::Preview
  def price_dropped
    user = User.first || User.new(email: "test@example.com", price_notification_threshold: 5.0, currency: "EUR")

    price_drops = [
      {
        title: "3-room flat in Rīga, Centrs",
        ad_type: "flat",
        location: "Brīvības iela 123, Centrs, Rīga",
        rooms: 3,
        area: 78.5,
        floor: "4/5",
        land_area: nil,
        previous_price: 125000,
        current_price: 115000,
        savings: 10000,
        percentage: 8.0,
        url: "https://www.ss.com/msg/lv/real-estate/flats/riga/centre/abcde.html"
      },
      {
        title: "2-room flat in Jūrmala, Majori",
        ad_type: "flat",
        location: "Jomas iela 45, Majori, Jūrmala",
        rooms: 2,
        area: 52.0,
        floor: "2/3",
        land_area: nil,
        previous_price: 89000,
        current_price: 82000,
        savings: 7000,
        percentage: 7.9,
        url: "https://www.ss.com/msg/lv/real-estate/flats/jurmala/majori/fghij.html"
      },
      {
        title: "House in Rīga district, Mārupe",
        ad_type: "house",
        location: "Ozolu iela 12, Mārupe, Rīgas rajons",
        rooms: 5,
        area: 180.0,
        floor: nil,
        land_area: 1200,
        previous_price: 320000,
        current_price: 295000,
        savings: 25000,
        percentage: 7.8,
        url: "https://www.ss.com/msg/lv/real-estate/houses/riga-region/marupe/klmno.html"
      }
    ]

    SsPriceDropMailer.price_dropped(user, price_drops)
  end
end
