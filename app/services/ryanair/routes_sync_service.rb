require "net/http"
require "json"

module Ryanair
  class RoutesSyncService
    ROUTES_API_URL = "https://www.ryanair.com/api/views/locate/searchWidget/routes/en/airport/RIX".freeze

    def call
      Rails.logger.info "[Ryanair::RoutesSyncService] Starting routes sync from RIX..."

      response = fetch_routes
      return { success: false, error: "Failed to fetch routes" } unless response

      destinations = parse_response(response)
      return { success: false, error: "No destinations found" } if destinations.empty?

      stats = sync_destinations(destinations)

      Rails.logger.info "[Ryanair::RoutesSyncService] Sync completed: #{stats[:created]} created, #{stats[:updated]} updated"

      { success: true, **stats }
    rescue StandardError => e
      Rails.logger.error "[Ryanair::RoutesSyncService] Error: #{e.message}"
      { success: false, error: e.message }
    end

    private

    def fetch_routes
      uri = URI(ROUTES_API_URL)
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
        Rails.logger.error "[Ryanair::RoutesSyncService] API returned #{response.code}"
        nil
      end
    end

    def parse_response(data)
      return [] unless data.is_a?(Array)

      data.map do |route|
        airport = route["arrivalAirport"]
        next unless airport

        {
          code: airport["code"],
          name: airport["name"],
          seo_name: airport["seoName"],
          city_name: airport.dig("city", "name"),
          city_code: airport.dig("city", "code"),
          country_name: airport.dig("country", "name"),
          country_code: airport.dig("country", "code"),
          currency_code: airport.dig("country", "currencyCode"),
          latitude: airport.dig("coordinates", "latitude"),
          longitude: airport.dig("coordinates", "longitude"),
          timezone: airport["timeZone"],
          is_base: airport["base"] || false,
          seasonal: route["seasonal"] || false
        }
      end.compact
    end

    def sync_destinations(destinations)
      created = 0
      updated = 0

      destinations.each do |attrs|
        destination = RyanairDestination.find_or_initialize_by(code: attrs[:code])

        if destination.new_record?
          created += 1
        else
          updated += 1
        end

        destination.assign_attributes(attrs.merge(last_synced_at: Time.current))
        destination.save!
      end

      { created: created, updated: updated, total: destinations.count }
    end
  end
end
