class FetchRyanairPriceJob < ApplicationJob
  queue_as :default

  def perform(flight_search_id)
    flight_search = RyanairFlightSearch.find_by(id: flight_search_id)

    unless flight_search
      Rails.logger.error "[FetchRyanairPriceJob] Flight search ##{flight_search_id} not found"
      return
    end

    Rails.logger.info "[FetchRyanairPriceJob] Fetching prices for flight search ##{flight_search_id}"

    result = Ryanair::PriceFetchService.new(flight_search).call

    if result[:success]
      Rails.logger.info "[FetchRyanairPriceJob] Prices fetched successfully: #{result[:total]}"
    else
      Rails.logger.error "[FetchRyanairPriceJob] Failed to fetch prices: #{result[:error]}"
    end
  end
end
