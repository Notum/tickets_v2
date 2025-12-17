class RyanairRouteRemovedMailerPreview < ActionMailer::Preview
  def route_removed
    user = User.first || User.new(email: "test@example.com")

    removed_route = {
      name: "Barcelona El Prat",
      code: "BCN",
      city_name: "Barcelona",
      country_name: "Spain"
    }

    affected_flights = [
      {
        date_out: Date.today + 14,
        date_in: Date.today + 21,
        total_price: 89.99
      },
      {
        date_out: Date.today + 30,
        date_in: Date.today + 37,
        total_price: 125.50
      },
      {
        date_out: Date.today + 60,
        date_in: Date.today + 67,
        total_price: nil
      }
    ]

    RyanairRouteRemovedMailer.route_removed(user, removed_route, affected_flights)
  end
end
