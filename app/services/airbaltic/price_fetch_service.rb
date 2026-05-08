require "net/http"
require "json"

module Airbaltic
  class PriceFetchService
    AVAIL_CALENDAR_API = "https://fly.airbaltic.com/json/fb/availCalendar".freeze

    def initialize(flight_search)
      @flight_search = flight_search
    end

    def call
      Rails.logger.info "[Airbaltic::PriceFetchService] Fetching prices for flight search ##{@flight_search.id}"

      price_data = fetch_total_price
      return update_with_error("Failed to fetch round-trip price") unless price_data

      save_prices(price_data)
    rescue StandardError => e
      Rails.logger.error "[Airbaltic::PriceFetchService] Error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      update_with_error(e.message)
    end

    private

    def fetch_total_price
      destination = @flight_search.airbaltic_destination
      date_out = @flight_search.date_out
      date_in = @flight_search.date_in

      params = {
        "sref" => "BBX",
        "originCode" => "RIX",
        "destinCode" => destination.code,
        "originType" => "A",
        "destinType" => "A",
        "tripType" => "return",
        "numAdt" => 1,
        "numChd" => 0,
        "numInf" => 0,
        "numYth" => 0,
        "departure" => date_out.strftime("%Y-%m-%d"),
        "return" => date_in.strftime("%Y-%m-%d")
      }

      response = fetch_api(AVAIL_CALENDAR_API, params)
      return nil unless response

      price_tabs = response.dig("response", "journeys", 0, "priceTabs")
      return nil unless price_tabs.is_a?(Array)

      out_str = date_out.strftime("%Y-%m-%d")
      in_str = date_in.strftime("%Y-%m-%d")
      tab = price_tabs.find { |t| t["outdate"] == out_str && t["indate"] == in_str }
      return nil unless tab && tab["hasPrice"] && tab["amount"]

      { total: tab["amount"].to_f, currency: tab["currency"] || "EUR" }
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

    def save_prices(price_data)
      new_total_price = price_data[:total]
      previous_total_price = @flight_search.total_price

      # New IBE API exposes only the combined RT total, not per-leg prices or
      # per-leg directness. Store the full amount in price_out, set price_in
      # to 0 so total_price (price_out + price_in) stays correct.
      @flight_search.update!(
        price_out: new_total_price,
        price_in: 0,
        is_direct_out: true,
        is_direct_in: true,
        status: "priced",
        priced_at: Time.current,
        api_response: { total: new_total_price, currency: price_data[:currency] }.to_json
      )

      @flight_search.record_price_if_changed(new_total_price, 0, new_total_price)

      Rails.logger.info "[Airbaltic::PriceFetchService] Price saved: TOTAL=#{new_total_price} #{price_data[:currency]}"

      result = { success: true, price_out: new_total_price, price_in: 0, total: new_total_price }

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
