module Bode
  class PriceFetchService
    def initialize(flight_search)
      @flight_search = flight_search
    end

    def call
      Rails.logger.info "[Bode::PriceFetchService] Fetching price for flight search ##{@flight_search.id}"

      destination = @flight_search.bode_destination
      result = FlightsFetchService.new(destination).call

      unless result[:success]
        return update_with_error(result[:error] || "Failed to fetch flights")
      end

      flights = result[:flights]

      # Find flight matching our date range
      matching_flight = flights.find do |f|
        f[:date_out] == @flight_search.date_out && f[:date_in] == @flight_search.date_in
      end

      if matching_flight
        update_with_price(matching_flight)
      else
        remove_unavailable_flight
      end
    rescue StandardError => e
      Rails.logger.error "[Bode::PriceFetchService] Error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      update_with_error(e.message)
    end

    private

    def update_with_price(flight_data)
      new_price = flight_data[:price]
      previous_price = @flight_search.price

      @flight_search.update!(
        price: new_price,
        airline: flight_data[:airline],
        order_url: flight_data[:order_url],
        free_seats: flight_data[:free_seats],
        nights: flight_data[:nights],
        status: "priced",
        priced_at: Time.current,
        api_response: flight_data.to_json
      )

      # Record price history if price changed
      @flight_search.record_price_if_changed(new_price)

      Rails.logger.info "[Bode::PriceFetchService] Price saved: #{new_price}€"

      result = { success: true, price: new_price }

      # Check for price drop
      if previous_price.present? && new_price < previous_price
        price_drop = previous_price - new_price
        result[:price_drop] = {
          flight_search_id: @flight_search.id,
          destination_name: @flight_search.bode_destination.name,
          date_out: @flight_search.date_out,
          date_in: @flight_search.date_in,
          previous_price: previous_price,
          current_price: new_price,
          savings: price_drop,
          order_url: @flight_search.order_url
        }
        Rails.logger.info "[Bode::PriceFetchService] Price dropped by #{price_drop}€!"
      end

      result
    end

    def update_with_error(message)
      @flight_search.update!(status: "error", api_response: { error: message }.to_json)
      { success: false, error: message }
    end

    def remove_unavailable_flight
      destination_name = @flight_search.bode_destination.name
      date_out = @flight_search.date_out
      date_in = @flight_search.date_in
      flight_id = @flight_search.id

      @flight_search.destroy!

      Rails.logger.info "[Bode::PriceFetchService] Removed unavailable flight ##{flight_id}: #{destination_name} (#{date_out} - #{date_in})"
      { success: false, removed: true, message: "Flight no longer available" }
    end
  end
end
