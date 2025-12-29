module Flydubai
  class OutboundDatesService
    CALENDAR_API = "https://www.flydubai.com/api/Calendar".freeze
    CACHE_EXPIRY = 13.hours
    ORIGIN = "RIX".freeze
    DESTINATION = "DXB".freeze

    def self.cache_key
      "flydubai_outbound_dates"
    end

    def call
      # Check cache first for fast response
      cached_dates = Rails.cache.read(self.class.cache_key)
      if cached_dates.present?
        Rails.logger.info "[Flydubai::OutboundDatesService] Returning #{cached_dates.count} cached dates"
        return cached_dates
      end

      Rails.logger.info "[Flydubai::OutboundDatesService] Cache miss, fetching outbound dates"

      flaresolverr = FlaresolverrService.new
      api_url = build_calendar_url

      begin
        response = flaresolverr.fetch(api_url)
      rescue FlaresolverrService::FlaresolverrError => e
        Rails.logger.error "[Flydubai::OutboundDatesService] FlareSolverr error: #{e.message}"
        return []
      end

      dates = parse_response(response, ORIGIN, DESTINATION)

      # Filter to only dates in the future
      result = dates.select { |d| d[:date] >= Date.current }
                    .uniq { |d| d[:date] }
                    .sort_by { |d| d[:date] }

      # Cache the result for future requests
      if result.any?
        Rails.cache.write(self.class.cache_key, result, expires_in: CACHE_EXPIRY)
        Rails.logger.info "[Flydubai::OutboundDatesService] Cached #{result.count} dates"
      end

      result
    rescue StandardError => e
      Rails.logger.error "[Flydubai::OutboundDatesService] Error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      []
    end

    private

    def build_calendar_url
      # Format: DD-Month-YYYY (e.g., 29-December-2025)
      from_date = Date.current.strftime("%-d-%B-%Y")

      "#{CALENDAR_API}/#{ORIGIN}/#{DESTINATION}?fromDate=#{from_date}&isOriginMetro=false&isDestMetro=false"
    end

    def parse_response(response, origin, destination)
      return [] unless response.is_a?(Hash) && response["routes"]

      # Find the route matching our origin and destination
      route = response["routes"].find { |r| r["origin"] == origin && r["dest"] == destination }
      return [] unless route && route["flightSchedules"]

      route["flightSchedules"].map do |schedule|
        # Parse date from format "2025-12-30T00:00:00"
        date = Date.parse(schedule.split("T").first)

        {
          date: date,
          is_direct: true # FlyDubai calendar doesn't indicate directness, assume direct
        }
      end.compact
    end
  end
end
