class RyanairNewRouteMailerPreview < ActionMailer::Preview
  def new_routes_available
    user = User.first || User.new(email: "test@example.com")

    new_routes = [
      {
        name: "Barcelona El Prat",
        code: "BCN",
        city_name: "Barcelona",
        country_name: "Spain"
      },
      {
        name: "Milan Bergamo",
        code: "BGY",
        city_name: "Milan",
        country_name: "Italy"
      },
      {
        name: "London Stansted",
        code: "STN",
        city_name: "London",
        country_name: "United Kingdom"
      }
    ]

    RyanairNewRouteMailer.new_routes_available(user, new_routes)
  end
end
