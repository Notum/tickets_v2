class DashboardsController < ApplicationController
  def bode
  end

  def ryanair
    @destinations_count = RyanairDestination.count
    @flight_searches_count = current_user.ryanair_flight_searches.count
    @recent_searches = current_user.ryanair_flight_searches.includes(:ryanair_destination).recent.limit(5)
  end

  def airbaltic
  end

  def norwegian
  end

  def salidzini
  end
end
