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

      # Get current destination codes from API
      api_codes = destinations.map { |d| d[:code] }

      stats = sync_destinations(destinations)

      # Announce new routes to all users
      announced_count = announce_new_routes

      # Handle removed routes
      removed_count = handle_removed_routes(api_codes)

      Rails.logger.info "[Ryanair::RoutesSyncService] Sync completed: #{stats[:created]} created, #{stats[:updated]} updated, #{announced_count} new routes announced, #{removed_count} routes removed"

      { success: true, **stats, announced: announced_count, removed: removed_count }
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

    def announce_new_routes
      # Find routes that haven't been announced yet
      new_routes = RyanairDestination.where(announced_at: nil)
      return 0 if new_routes.empty?

      # Prepare route data for email
      new_routes_data = new_routes.map do |route|
        {
          name: route.name,
          code: route.code,
          city_name: route.city_name,
          country_name: route.country_name
        }
      end

      # Send email to all users
      users = User.all
      users.each do |user|
        RyanairNewRouteMailer.new_routes_available(user, new_routes_data).deliver_later
        Rails.logger.info "[Ryanair::RoutesSyncService] Sent new routes email to #{user.email}"
      end

      # Mark routes as announced
      new_routes.update_all(announced_at: Time.current)

      new_routes_data.count
    end

    def handle_removed_routes(api_codes)
      # Find destinations that exist in DB but not in API response
      removed_destinations = RyanairDestination.where.not(code: api_codes)
      return 0 if removed_destinations.empty?

      removed_count = 0

      removed_destinations.each do |destination|
        Rails.logger.info "[Ryanair::RoutesSyncService] Route removed: #{destination.name} (#{destination.code})"

        # Prepare route data for email
        removed_route_data = {
          name: destination.name,
          code: destination.code,
          city_name: destination.city_name,
          country_name: destination.country_name
        }

        # Find affected users and their flight searches
        affected_searches = destination.ryanair_flight_searches.includes(:user)
        users_with_flights = affected_searches.group_by(&:user)

        # Send notification to each affected user
        users_with_flights.each do |user, flights|
          affected_flights_data = flights.map do |flight|
            {
              date_out: flight.date_out,
              date_in: flight.date_in,
              total_price: flight.total_price
            }
          end

          RyanairRouteRemovedMailer.route_removed(user, removed_route_data, affected_flights_data).deliver_later
          Rails.logger.info "[Ryanair::RoutesSyncService] Sent route removed email to #{user.email} for #{destination.code}"
        end

        # Delete destination (will cascade delete flight searches due to dependent: :destroy)
        destination.destroy!
        removed_count += 1
      end

      removed_count
    end
  end
end
