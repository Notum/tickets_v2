require "net/http"
require "json"

module Airbaltic
  class DestinationsSyncService
    # TripX API provides AirBaltic Holidays destinations
    DESTINATIONS_API = "https://wp.tripx.eu/wp-json/tripx/v1/destinations?frontDomain=airbalticholidays.com&countryCode=eu".freeze

    def call
      Rails.logger.info "[Airbaltic::DestinationsSyncService] Fetching destinations from TripX API..."

      response = fetch_destinations
      return { success: false, error: "Failed to fetch destinations" } unless response

      destinations = parse_response(response)
      return { success: false, error: "No destinations found" } if destinations.empty?

      Rails.logger.info "[Airbaltic::DestinationsSyncService] Found #{destinations.count} destinations"

      # Get current destination codes from API
      api_codes = destinations.map { |d| d[:code] }

      stats = sync_destinations(destinations)

      # Deactivate destinations no longer in API
      deactivated = deactivate_removed_destinations(api_codes)

      Rails.logger.info "[Airbaltic::DestinationsSyncService] Sync completed: #{stats[:created]} created, #{stats[:updated]} updated, #{deactivated} deactivated"

      { success: true, **stats, deactivated: deactivated }
    rescue StandardError => e
      Rails.logger.error "[Airbaltic::DestinationsSyncService] Error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      { success: false, error: e.message }
    end

    private

    def fetch_destinations
      uri = URI(DESTINATIONS_API)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 15
      http.read_timeout = 30

      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"
      request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"

      response = http.request(request)

      if response.code == "200"
        JSON.parse(response.body)
      else
        Rails.logger.error "[Airbaltic::DestinationsSyncService] API returned #{response.code}"
        nil
      end
    end

    def parse_response(data)
      return [] unless data.is_a?(Array)

      destinations = []

      data.each do |country|
        country_name = country["name"]
        country_code = country["code"]

        next unless country["destinations"].is_a?(Array)

        country["destinations"].each do |dest|
          code = dest["code"]
          name = dest["name"]

          # Skip if no valid airport code (3 letters)
          next unless code.is_a?(String) && code.match?(/\A[A-Z]{3}\z/)

          destinations << {
            code: code,
            name: name,
            city_name: name,
            country_name: country_name,
            country_code: country_code
          }
        end
      end

      destinations
    end

    def sync_destinations(destinations)
      created = 0
      updated = 0

      destinations.each do |attrs|
        destination = AirbalticDestination.find_or_initialize_by(code: attrs[:code])

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

    def deactivate_removed_destinations(api_codes)
      # Deactivate destinations that are no longer in the API
      AirbalticDestination.where(active: true).where.not(code: api_codes).update_all(active: false)
    end
  end
end
