class PriceDropMailerPreview < ActionMailer::Preview
  def price_dropped
    user = User.first || User.new(email: "test@example.com", price_notification_threshold: 5.0)

    price_drops = [
      {
        destination_name: "Barcelona",
        destination_code: "BCN",
        date_out: Date.today + 14,
        date_in: Date.today + 21,
        previous_price: 89.99,
        current_price: 65.50,
        savings: 24.49
      },
      {
        destination_name: "Milan Bergamo",
        destination_code: "BGY",
        date_out: Date.today + 30,
        date_in: Date.today + 35,
        previous_price: 120.00,
        current_price: 99.00,
        savings: 21.00
      },
      {
        destination_name: "London Stansted",
        destination_code: "STN",
        date_out: Date.today + 45,
        date_in: Date.today + 52,
        previous_price: 75.00,
        current_price: 55.00,
        savings: 20.00
      }
    ]

    PriceDropMailer.price_dropped(user, price_drops)
  end
end
