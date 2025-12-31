require "net/http"
require "json"

module Turkish
  class DestinationsSearchService
    LOCATIONS_API = "https://www.turkishairlines.com/api/v1/booking/locations/TK/en".freeze

    def initialize(query)
      @query = query
    end

    def call
      return [] if @query.blank? || @query.length < 2

      Rails.logger.info "[Turkish::DestinationsSearchService] Searching for: #{@query}"

      response = fetch_with_flaresolverr
      parse_destinations(response)
    rescue FlaresolverrService::FlaresolverrError => e
      Rails.logger.error "[Turkish::DestinationsSearchService] FlareSolverr error: #{e.message}"
      # Fallback to direct request in development
      if Rails.env.development?
        Rails.logger.info "[Turkish::DestinationsSearchService] Falling back to direct request"
        response = make_direct_request
        parse_destinations(response)
      else
        []
      end
    rescue StandardError => e
      Rails.logger.error "[Turkish::DestinationsSearchService] Error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      []
    end

    private

    def fetch_with_flaresolverr
      url = build_url
      Rails.logger.info "[Turkish::DestinationsSearchService] Fetching via FlareSolverr: #{url}"

      flaresolverr = FlaresolverrService.new
      flaresolverr.fetch(url)
    end

    def build_url
      uri = URI(LOCATIONS_API)
      uri.query = URI.encode_www_form({
        "searchText" => @query,
        "bookerType" => "TICKETING"
      })
      uri.to_s
    end

    def make_direct_request
      uri = URI(build_url)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 15

      request = Net::HTTP::Get.new(uri)

      # Set headers to mimic browser request
      request["Accept"] = "application/json"
      request["Accept-Language"] = "en"
      request["Origin"] = "https://www.turkishairlines.com"
      request["Referer"] = "https://www.turkishairlines.com/en-int/flights/booking/"
      request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
      request["x-country"] = "int"
      request["x-platform"] = "WEB"

      Rails.logger.info "[Turkish::DestinationsSearchService] Making direct GET to #{uri}"
      response = http.request(request)
      Rails.logger.info "[Turkish::DestinationsSearchService] Response: #{response.code} (#{response.body.length} bytes)"

      if response.code.to_i == 200
        JSON.parse(response.body)
      else
        Rails.logger.warn "[Turkish::DestinationsSearchService] HTTP #{response.code}: #{response.body.first(500)}"
        { "success" => false }
      end
    end

    def parse_destinations(response)
      return [] unless response.is_a?(Hash) && response["success"] == true && response["data"]

      data = response["data"]
      destinations = []

      # Parse locations.ports array (main structure)
      ports = data.dig("locations", "ports")
      if ports.is_a?(Array)
        ports.each do |port|
          next unless port["code"].present?

          # Skip RIX (origin airport)
          next if port["code"] == "RIX"

          # Use city name as display name (more user-friendly)
          city_name = port.dig("city", "name") || port["name"]

          destinations << {
            code: port["code"],
            name: city_name,
            city_name: city_name,
            city_code: port.dig("city", "code") || port["code"],
            country_code: port.dig("country", "code"),
            country_name: port.dig("country", "name")
          }
        end
      end

      # Remove duplicates by code
      destinations.uniq { |d| d[:code] }
    end
  end
end
