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
      price_out = extract_lowest_price(data, "outbound")
      price_in = extract_lowest_price(data, "inbound")

      if price_out && price_in
        @flight_search.update!(
          price_out: price_out,
          price_in: price_in,
          status: "priced",
          priced_at: Time.current,
          api_response: data.to_json
        )

        Rails.logger.info "[Ryanair::PriceFetchService] Prices saved: OUT=#{price_out}, IN=#{price_in}, TOTAL=#{@flight_search.total_price}"

        { success: true, price_out: price_out, price_in: price_in, total: @flight_search.total_price }
      else
        update_with_error("Could not extract prices from response")
      end
    end

    def extract_lowest_price(data, direction)
      # Fare finder API returns: { "fares": [{ "outbound": {...}, "inbound": {...}, "summary": {...} }] }
      fares = data.dig("fares")
      return nil unless fares.is_a?(Array) && fares.any?

      lowest_price = nil

      fares.each do |fare|
        leg = fare.dig(direction)
        next unless leg

        price_value = leg.dig("price", "value")
        next unless price_value

        price = price_value.to_f
        lowest_price = price if lowest_price.nil? || price < lowest_price
      end

      lowest_price
    end

    def update_with_error(message)
      @flight_search.update!(status: "error", api_response: { error: message }.to_json)
      { success: false, error: message }
    end
  end
end
