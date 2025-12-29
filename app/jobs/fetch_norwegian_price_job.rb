class FetchNorwegianPriceJob < ApplicationJob
  queue_as :default

  def perform(flight_search_id)
    flight_search = NorwegianFlightSearch.find_by(id: flight_search_id)

    unless flight_search
      Rails.logger.warn "[FetchNorwegianPriceJob] Flight search ##{flight_search_id} not found"
      return
    end

    Rails.logger.info "[FetchNorwegianPriceJob] Fetching price for flight search ##{flight_search_id}"

    Norwegian::PriceFetchService.new(flight_search).call
  end
end
