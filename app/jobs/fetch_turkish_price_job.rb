class FetchTurkishPriceJob < ApplicationJob
  queue_as :default

  def perform(flight_search_id)
    flight_search = TurkishFlightSearch.find_by(id: flight_search_id)
    return unless flight_search

    Rails.logger.info "[FetchTurkishPriceJob] Fetching price for flight search ##{flight_search_id}"

    Turkish::PriceFetchService.new(flight_search).call
  end
end
