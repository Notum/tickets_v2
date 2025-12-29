class FetchFlydubaiPriceJob < ApplicationJob
  queue_as :default

  def perform(flight_search_id)
    flight_search = FlydubaiFlightSearch.find_by(id: flight_search_id)

    unless flight_search
      Rails.logger.warn "[FetchFlydubaiPriceJob] Flight search ##{flight_search_id} not found"
      return
    end

    Rails.logger.info "[FetchFlydubaiPriceJob] Fetching price for flight search ##{flight_search_id}"

    Flydubai::PriceFetchService.new(flight_search).call
  end
end
