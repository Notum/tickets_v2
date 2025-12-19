class FetchAirbalticPriceJob < ApplicationJob
  queue_as :default

  def perform(flight_search_id)
    flight_search = AirbalticFlightSearch.find_by(id: flight_search_id)

    unless flight_search
      Rails.logger.error "[FetchAirbalticPriceJob] Flight search ##{flight_search_id} not found"
      return
    end

    Rails.logger.info "[FetchAirbalticPriceJob] Fetching prices for flight search ##{flight_search_id}"

    result = Airbaltic::PriceFetchService.new(flight_search).call

    if result[:success]
      Rails.logger.info "[FetchAirbalticPriceJob] Prices fetched successfully: #{result[:total]}"
    else
      Rails.logger.error "[FetchAirbalticPriceJob] Failed to fetch prices: #{result[:error]}"
    end
  end
end
