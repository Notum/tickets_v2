require "net/http"
require "json"

module Airbaltic
  class OutboundDatesService
    BASE_URL = "https://www.airbaltic.com/api/fsf/outbound".freeze

    def initialize(destination_code)
      @destination_code = destination_code
    end

    def call
      Rails.logger.info "[Airbaltic::OutboundDatesService] Fetching outbound dates RIX -> #{@destination_code}"

      response = fetch_dates
      return [] unless response && response["success"]

      parse_dates(response["data"])
    rescue StandardError => e
      Rails.logger.error "[Airbaltic::OutboundDatesService] Error: #{e.message}"
      []
    end

    private

    def fetch_dates
      # Search from today to 1 year ahead
      start_date = Date.today.strftime("%Y-%m-%d")
      end_date = (Date.today + 1.year).strftime("%Y-%m-%d")

      params = {
        "flightMode" => "return",
        "origin" => "RIX",
        "destin" => @destination_code,
        "startDate" => start_date,
        "endDate" => end_date
      }

      uri = URI(BASE_URL)
      uri.query = URI.encode_www_form(params)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"
      request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"

      response = http.request(request)

      if response.code == "200"
        JSON.parse(response.body)
      else
        Rails.logger.error "[Airbaltic::OutboundDatesService] API returned #{response.code}: #{response.body}"
        nil
      end
    end

    def parse_dates(data)
      return [] unless data.is_a?(Array)

      # Return array of hashes with date, price, and isDirect
      # Include dates even when price is null (flight exists but price not cached)
      # Only include DIRECT flights
      data.filter_map do |item|
        next unless item["date"]
        next unless item["isDirect"] == true  # Only direct flights

        {
          date: Date.parse(item["date"]),
          price: item["price"]&.to_f,
          is_direct: true
        }
      end.sort_by { |d| d[:date] }
    rescue ArgumentError => e
      Rails.logger.error "[Airbaltic::OutboundDatesService] Date parsing error: #{e.message}"
      []
    end
  end
end
