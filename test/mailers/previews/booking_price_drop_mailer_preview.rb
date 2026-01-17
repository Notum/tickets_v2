class BookingPriceDropMailerPreview < ActionMailer::Preview
  def price_dropped
    user = User.first || User.new(email: "test@example.com", price_notification_threshold: 5.0, currency: "EUR")

    price_drops = [
      {
        hotel_name: "Port Europa",
        city_name: "Calpe, Spain",
        room_name: "Budget Double Room",
        check_in: Date.today + 14,
        check_out: Date.today + 21,
        previous_price: 1250.00,
        current_price: 1050.00,
        savings: 200.00,
        currency: "EUR"
      },
      {
        hotel_name: "Hotel Arts Barcelona",
        city_name: "Barcelona, Spain",
        room_name: "Deluxe Sea View Room",
        check_in: Date.today + 30,
        check_out: Date.today + 33,
        previous_price: 890.00,
        current_price: 750.00,
        savings: 140.00,
        currency: "EUR"
      },
      {
        hotel_name: "Marriott Downtown",
        city_name: "New York, USA",
        room_name: nil,
        check_in: Date.today + 45,
        check_out: Date.today + 48,
        previous_price: 650.00,
        current_price: 520.00,
        savings: 130.00,
        currency: "USD"
      }
    ]

    BookingPriceDropMailer.price_dropped(user, price_drops)
  end
end
