require "net/http"
require "json"

module Airbaltic
  class InboundDatesService
    BASE_URL = "https://www.airbaltic.com/api/fsf/inbound".freeze

    def initialize(destination_code, date_out)
      @destination_code = destination_code
      @date_out = date_out.is_a?(Date) ? date_out : Date.parse(date_out)
    end

    def call
      Rails.logger.info "[Airbaltic::InboundDatesService] Fetching inbound dates #{@destination_code} -> RIX for outbound #{@date_out}"

      response = fetch_dates
      return [] unless response && response["success"]

      parse_dates(response["data"])
    rescue StandardError => e
      Rails.logger.error "[Airbaltic::InboundDatesService] Error: #{e.message}"
      []
    end

    private

    def fetch_dates
      # Search from outbound date to 1 year ahead
      start_date = @date_out.strftime("%Y-%m-%d")
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
        Rails.logger.error "[Airbaltic::InboundDatesService] API returned #{response.code}: #{response.body}"
        nil
      end
    end

    def parse_dates(data)
      # The inbound API returns data in different structure: { flights: [...] }
      flights = data.is_a?(Hash) ? data["flights"] : data
      return [] unless flights.is_a?(Array)

      # Return array of hashes with date, price, is_direct and outbound_price
      # Include dates even when price is null (flight exists but price not cached)
      # Filter to only include dates after the outbound date
      # Only include DIRECT flights
      flights.filter_map do |item|
        next unless item["date"]
        next unless item["isDirect"] == true  # Only direct flights

        date = Date.parse(item["date"])
        next if date <= @date_out

        {
          date: date,
          price: item["price"]&.to_f,
          is_direct: true,
          outbound_price: item["outboundPrice"]&.to_f
        }
      end.sort_by { |d| d[:date] }
    rescue ArgumentError => e
      Rails.logger.error "[Airbaltic::InboundDatesService] Date parsing error: #{e.message}"
      []
    end
  end
end
