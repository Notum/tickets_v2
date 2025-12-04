class FetchBodePriceJob < ApplicationJob
  queue_as :default

  def perform(flight_search_id)
    flight_search = BodeFlightSearch.find_by(id: flight_search_id)

    unless flight_search
      Rails.logger.warn "[FetchBodePriceJob] Flight search ##{flight_search_id} not found"
      return
    end

    Rails.logger.info "[FetchBodePriceJob] Fetching price for flight search ##{flight_search_id}"

    result = Bode::PriceFetchService.new(flight_search).call

    if result[:success]
      Rails.logger.info "[FetchBodePriceJob] Successfully fetched price: #{result[:price]}€"
    else
      Rails.logger.error "[FetchBodePriceJob] Failed to fetch price: #{result[:error]}"
    end
  end
end
