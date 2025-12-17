class RyanairRouteRemovedMailer < ApplicationMailer
  def route_removed(user, removed_route, affected_flights)
    @user = user
    @removed_route = removed_route
    @affected_flights = affected_flights

    mail(
      to: @user.email,
      subject: "Ryanair Route Discontinued: #{removed_route[:name]} (#{removed_route[:code]})"
    )
  end
end
