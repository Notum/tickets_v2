class BodePriceDropMailerPreview < ActionMailer::Preview
  def price_dropped
    user = User.first || User.new(email: "test@example.com", price_notification_threshold: 5.0)

    price_drops = [
      {
        destination_name: "Рига - Анталья - Рига",
        date_out: Date.today + 14,
        date_in: Date.today + 21,
        previous_price: 385,
        current_price: 335,
        savings: 50,
        order_url: "https://bode.lv/ru/charteri/charterid/45822202114690792"
      },
      {
        destination_name: "Рига - Тенерифе - Рига",
        date_out: Date.today + 30,
        date_in: Date.today + 37,
        previous_price: 420,
        current_price: 380,
        savings: 40,
        order_url: "https://bode.lv/ru/charteri/charterid/12345678901234567"
      },
      {
        destination_name: "Рига - Дубай - Рига",
        date_out: Date.today + 45,
        date_in: Date.today + 52,
        previous_price: 599,
        current_price: 529,
        savings: 70,
        order_url: "https://bode.lv/ru/charteri/charterid/98765432109876543"
      }
    ]

    BodePriceDropMailer.price_dropped(user, price_drops)
  end
end
