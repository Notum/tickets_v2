require "net/http"
require "json"

module Ryanair
  class PriceFetchService
    # Use the fare finder API which doesn't require authentication
    FARE_FINDER_API = "https://www.ryanair.com/api/farfnd/3/roundTripFares".freeze

    def initialize(flight_search)
      @flight_search = flight_search
    end

    def call
      Rails.logger.info "[Ryanair::PriceFetchService] Fetching prices for flight search ##{@flight_search.id}"

      response = fetch_fares
      return update_with_error("Failed to fetch fares") unless response

      # Parse and save prices
      parse_and_save_prices(response)
    rescue StandardError => e
      Rails.logger.error "[Ryanair::PriceFetchService] Error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      update_with_error(e.message)
    end

    private

    def fetch_fares
      uri = build_fare_finder_uri
      Rails.logger.info "[Ryanair::PriceFetchService] Fetching: #{uri}"

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 15
      http.read_timeout = 30

      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"
      request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

      response = http.request(request)

      if response.code == "200"
        JSON.parse(response.body)
      else
        Rails.logger.error "[Ryanair::PriceFetchService] API returned #{response.code}: #{response.body}"
        nil
      end
    end

    def build_fare_finder_uri
      destination = @flight_search.ryanair_destination
      date_out = @flight_search.date_out
      date_in = @flight_search.date_in

      # Add flex days (2 days before and after)
      params = {
        "departureAirportIataCode" => "RIX",
        "arrivalAirportIataCode" => destination.code,
        "outboundDepartureDateFrom" => (date_out - 2).strftime("%Y-%m-%d"),
        "outboundDepartureDateTo" => (date_out + 2).strftime("%Y-%m-%d"),
        "inboundDepartureDateFrom" => (date_in - 2).strftime("%Y-%m-%d"),
        "inboundDepartureDateTo" => (date_in + 2).strftime("%Y-%m-%d"),
        "currency" => "EUR",
        "adultPaxCount" => 1
      }

      uri = URI(FARE_FINDER_API)
      uri.query = URI.encode_www_form(params)
      uri
    end

    def parse_and_save_prices(data)
      outbound_data = extract_best_fare(data, "outbound")
      inbound_data = extract_best_fare(data, "inbound")

      if outbound_data && inbound_data
        new_total_price = outbound_data[:price] + inbound_data[:price]

        @flight_search.update!(
          price_out: outbound_data[:price],
          price_in: inbound_data[:price],
          departure_time_out: outbound_data[:departure_time],
          arrival_time_out: outbound_data[:arrival_time],
          departure_time_in: inbound_data[:departure_time],
          arrival_time_in: inbound_data[:arrival_time],
          status: "priced",
          priced_at: Time.current,
          api_response: data.to_json
        )

        # Record price history if price changed
        @flight_search.record_price_if_changed(outbound_data[:price], inbound_data[:price], new_total_price)

        Rails.logger.info "[Ryanair::PriceFetchService] Prices saved: OUT=#{outbound_data[:price]}, IN=#{inbound_data[:price]}, TOTAL=#{@flight_search.total_price}"

        { success: true, price_out: outbound_data[:price], price_in: inbound_data[:price], total: @flight_search.total_price }
      else
        update_with_error("Could not extract prices from response")
      end
    end

    def extract_best_fare(data, direction)
      # Fare finder API returns: { "fares": [{ "outbound": {...}, "inbound": {...}, "summary": {...} }] }
      fares = data.dig("fares")
      return nil unless fares.is_a?(Array) && fares.any?

      best_fare = nil
      lowest_price = nil

      fares.each do |fare|
        leg = fare.dig(direction)
        next unless leg

        price_value = leg.dig("price", "value")
        next unless price_value

        price = price_value.to_f
        if lowest_price.nil? || price < lowest_price
          lowest_price = price
          best_fare = leg
        end
      end

      return nil unless best_fare

      {
        price: lowest_price,
        departure_time: parse_datetime(best_fare.dig("departureDate")),
        arrival_time: parse_datetime(best_fare.dig("arrivalDate"))
      }
    end

    def parse_datetime(datetime_string)
      return nil unless datetime_string.present?
      Time.parse(datetime_string)
    rescue ArgumentError
      nil
    end

    def update_with_error(message)
      @flight_search.update!(status: "error", api_response: { error: message }.to_json)
      { success: false, error: message }
    end
  end
end
