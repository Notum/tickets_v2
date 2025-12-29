require "net/http"
require "json"

module Norwegian
  class DestinationsSyncService
    TRAVELTIP_API = "https://www.norwegian.com/api/affinity/traveltip/search".freeze

    def call
      Rails.logger.info "[Norwegian::DestinationsSyncService] Starting destinations sync from RIX..."

      # Fetch destinations from 3 date ranges to cover ~12 months
      # Use FlareSolverr to bypass Cloudflare bot protection
      all_destinations = {}
      flaresolverr = FlaresolverrService.new

      date_ranges.each do |range|
        api_url = build_api_url(range[:start], range[:end])
        Rails.logger.info "[Norwegian::DestinationsSyncService] Fetching via FlareSolverr: #{api_url}"

        begin
          response = flaresolverr.fetch(api_url)
        rescue FlaresolverrService::FlaresolverrError => e
          Rails.logger.error "[Norwegian::DestinationsSyncService] FlareSolverr error: #{e.message}"
          next
        end

        next unless response.is_a?(Hash)

        parse_response(response).each do |dest|
          # Merge by iatacode, keeping the first occurrence
          all_destinations[dest[:code]] ||= dest
        end

        # Small delay between requests to be polite
        sleep 1
      end

      if all_destinations.empty?
        return { success: false, error: "No destinations found" }
      end

      destinations = all_destinations.values
      Rails.logger.info "[Norwegian::DestinationsSyncService] Found #{destinations.count} unique destinations"

      # Get current destination codes from API
      api_codes = destinations.map { |d| d[:code] }

      stats = sync_destinations(destinations)

      # Announce new routes to all users
      announced_count = announce_new_routes

      # Handle removed routes
      removed_count = handle_removed_routes(api_codes)

      Rails.logger.info "[Norwegian::DestinationsSyncService] Sync completed: #{stats[:created]} created, #{stats[:updated]} updated, #{announced_count} new routes announced, #{removed_count} routes removed"

      { success: true, **stats, announced: announced_count, removed: removed_count }
    rescue StandardError => e
      Rails.logger.error "[Norwegian::DestinationsSyncService] Error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      { success: false, error: e.message }
    end

    private

    def date_ranges
      # Generate 3 date ranges covering ~12 months from today
      today = Date.current
      [
        { start: today, end: today + 4.months - 1.day },
        { start: today + 4.months, end: today + 8.months - 1.day },
        { start: today + 8.months, end: today + 12.months - 1.day }
      ]
    end

    def build_api_url(start_date, end_date)
      params = {
        "departureCity" => "RIX",
        "outboundDate" => start_date.strftime("%Y-%m-%dT00:00:00"),
        "lastOutboundDate" => end_date.strftime("%Y-%m-%dT00:00:00"),
        "destinationGroup" => "12",
        "maxPrice" => "-1",
        "splitDatesInto" => "3",
        "useDates" => "true",
        "currencyCode" => "EUR",
        "temperatureUnit" => "C",
        "isFirstRequestFetched" => "true",
        "numberOfMonths" => "4",
        "culture" => "en-BZ",
        "marketCode" => "en"
      }

      uri = URI(TRAVELTIP_API)
      uri.query = URI.encode_www_form(params)
      uri.to_s
    end

    def parse_response(data)
      return [] unless data.is_a?(Hash)

      result_list = data["resultList"]
      return [] unless result_list.is_a?(Array)

      result_list.map do |item|
        code = item["iatacode"]
        next unless code.present?

        {
          code: code,
          name: item["displayName"] || code,
          city_name: item["cityName"],
          country_name: item["countryName"]
        }
      end.compact
    end

    def sync_destinations(destinations)
      created = 0
      updated = 0

      destinations.each do |attrs|
        destination = NorwegianDestination.find_or_initialize_by(code: attrs[:code])

        if destination.new_record?
          created += 1
        else
          updated += 1
        end

        destination.assign_attributes(attrs.merge(last_synced_at: Time.current, active: true))
        destination.save!
      end

      { created: created, updated: updated, total: destinations.count }
    end

    def announce_new_routes
      # Find routes that haven't been announced yet
      new_routes = NorwegianDestination.where(announced_at: nil)
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
        NorwegianNewRouteMailer.new_routes_available(user, new_routes_data).deliver_later
        Rails.logger.info "[Norwegian::DestinationsSyncService] Sent new routes email to #{user.email}"
      end

      # Mark routes as announced
      new_routes.update_all(announced_at: Time.current)

      new_routes_data.count
    end

    def handle_removed_routes(api_codes)
      # Find active destinations that exist in DB but not in API response
      removed_destinations = NorwegianDestination.where(active: true).where.not(code: api_codes)
      return 0 if removed_destinations.empty?

      removed_count = 0

      removed_destinations.each do |destination|
        Rails.logger.info "[Norwegian::DestinationsSyncService] Route no longer available: #{destination.name} (#{destination.code})"

        # Mark as inactive instead of deleting
        destination.update!(active: false)
        removed_count += 1
      end

      removed_count
    end
  end
end
