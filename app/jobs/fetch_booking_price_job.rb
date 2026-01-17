class FetchBookingPriceJob < ApplicationJob
  queue_as :default

  def perform(booking_search_id)
    booking_search = BookingSearch.find_by(id: booking_search_id)
    return unless booking_search

    Rails.logger.info "[FetchBookingPriceJob] Fetching price for search ##{booking_search_id}"

    Booking::PriceFetchService.new(booking_search).call
  end
end
