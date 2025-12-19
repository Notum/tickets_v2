require "net/http"
require "json"

module Airbaltic
  class PriceFetchService
    OUTBOUND_API = "https://www.airbaltic.com/api/fsf/outbound".freeze
    INBOUND_API = "https://www.airbaltic.com/api/fsf/inbound".freeze

    def initialize(flight_search)
      @flight_search = flight_search
    end

    def call
      Rails.logger.info "[Airbaltic::PriceFetchService] Fetching prices for flight search ##{@flight_search.id}"

      # Fetch outbound price for the specific date
      outbound_data = fetch_outbound_price
      return update_with_error("Failed to fetch outbound price") unless outbound_data

      # Fetch inbound price for the specific date
      inbound_data = fetch_inbound_price
      return update_with_error("Failed to fetch inbound price") unless inbound_data

      # Save prices
      save_prices(outbound_data, inbound_data)
    rescue StandardError => e
      Rails.logger.error "[Airbaltic::PriceFetchService] Error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      update_with_error(e.message)
    end

    private

    def fetch_outbound_price
      destination = @flight_search.airbaltic_destination
      date_out = @flight_search.date_out

      # Use a small date range around the target date
      params = {
        "flightMode" => "return",
        "origin" => "RIX",
        "destin" => destination.code,
        "startDate" => date_out.strftime("%Y-%m-%d"),
        "endDate" => (date_out + 1.day).strftime("%Y-%m-%d")
      }

      response = fetch_api(OUTBOUND_API, params)
      return nil unless response && response["success"]

      # Find the exact date in the response
      data = response["data"]
      return nil unless data.is_a?(Array)

      date_data = data.find { |d| d["date"] == date_out.strftime("%Y-%m-%d") }
      return nil unless date_data && date_data["price"]

      {
        price: date_data["price"].to_f,
        is_direct: date_data["isDirect"] == true
      }
    end

    def fetch_inbound_price
      destination = @flight_search.airbaltic_destination
      date_out = @flight_search.date_out
      date_in = @flight_search.date_in

      # Fetch inbound dates starting from outbound date
      params = {
        "flightMode" => "return",
        "origin" => "RIX",
        "destin" => destination.code,
        "startDate" => date_out.strftime("%Y-%m-%d"),
        "endDate" => (date_in + 1.day).strftime("%Y-%m-%d")
      }

      response = fetch_api(INBOUND_API, params)
      return nil unless response && response["success"]

      # Inbound API returns data in different structure: { flights: [...] }
      data = response["data"]
      flights = data.is_a?(Hash) ? data["flights"] : data
      return nil unless flights.is_a?(Array)

      date_data = flights.find { |d| d["date"] == date_in.strftime("%Y-%m-%d") }
      return nil unless date_data && date_data["price"]

      {
        price: date_data["price"].to_f,
        is_direct: date_data["isDirect"] == true
      }
    end

    def fetch_api(url, params)
      uri = URI(url)
      uri.query = URI.encode_www_form(params)

      Rails.logger.info "[Airbaltic::PriceFetchService] Fetching: #{uri}"

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
        Rails.logger.error "[Airbaltic::PriceFetchService] API returned #{response.code}: #{response.body}"
        nil
      end
    end

    def save_prices(outbound_data, inbound_data)
      new_total_price = outbound_data[:price] + inbound_data[:price]
      previous_total_price = @flight_search.total_price

      @flight_search.update!(
        price_out: outbound_data[:price],
        price_in: inbound_data[:price],
        is_direct_out: outbound_data[:is_direct],
        is_direct_in: inbound_data[:is_direct],
        status: "priced",
        priced_at: Time.current,
        api_response: { outbound: outbound_data, inbound: inbound_data }.to_json
      )

      # Record price history if price changed
      @flight_search.record_price_if_changed(outbound_data[:price], inbound_data[:price], new_total_price)

      Rails.logger.info "[Airbaltic::PriceFetchService] Prices saved: OUT=#{outbound_data[:price]}, IN=#{inbound_data[:price]}, TOTAL=#{@flight_search.total_price}"

      result = { success: true, price_out: outbound_data[:price], price_in: inbound_data[:price], total: @flight_search.total_price }

      # Check for price drop
      if previous_total_price.present? && new_total_price < previous_total_price
        price_drop = previous_total_price - new_total_price
        result[:price_drop] = {
          flight_search_id: @flight_search.id,
          destination_name: @flight_search.airbaltic_destination.name,
          destination_code: @flight_search.airbaltic_destination.code,
          date_out: @flight_search.date_out,
          date_in: @flight_search.date_in,
          previous_price: previous_total_price,
          current_price: new_total_price,
          savings: price_drop
        }
        Rails.logger.info "[Airbaltic::PriceFetchService] Price dropped by #{price_drop} EUR!"
      end

      result
    end

    def update_with_error(message)
      @flight_search.update!(status: "error", api_response: { error: message }.to_json)
      { success: false, error: message }
    end
  end
end
