class RefreshAllRyanairPricesJob < ApplicationJob
  queue_as :default

  def perform
    flight_searches = RyanairFlightSearch.where(status: "priced").or(RyanairFlightSearch.where(status: "error"))

    Rails.logger.info "[RefreshAllRyanairPricesJob] Refreshing prices for #{flight_searches.count} flight searches"

    flight_searches.find_each do |search|
      # Skip if flight dates are in the past
      if search.date_out < Date.current
        Rails.logger.info "[RefreshAllRyanairPricesJob] Skipping flight search ##{search.id} - departure date is in the past"
        next
      end

      FetchRyanairPriceJob.perform_later(search.id)
    end

    Rails.logger.info "[RefreshAllRyanairPricesJob] Queued all price refresh jobs"
  end
end
