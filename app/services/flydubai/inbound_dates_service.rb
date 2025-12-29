module Flydubai
  class InboundDatesService
    CALENDAR_API = "https://www.flydubai.com/api/Calendar".freeze
    CACHE_EXPIRY = 13.hours
    ORIGIN = "DXB".freeze  # Return flight from Dubai
    DESTINATION = "RIX".freeze  # Back to Riga

    def self.cache_key
      "flydubai_inbound_dates"
    end

    def initialize(date_out)
      @date_out = date_out.is_a?(Date) ? date_out : Date.parse(date_out)
    end

    def call
      # Check cache first for fast response
      cached_dates = Rails.cache.read(self.class.cache_key)
      if cached_dates.present?
        # Filter cached dates to only show dates after the selected outbound date
        filtered = cached_dates.select { |d| d[:date] > @date_out }
        Rails.logger.info "[Flydubai::InboundDatesService] Returning #{filtered.count} cached inbound dates (after #{@date_out})"
        return filtered
      end

      Rails.logger.info "[Flydubai::InboundDatesService] Cache miss, fetching inbound dates"

      flaresolverr = FlaresolverrService.new
      api_url = build_calendar_url

      begin
        response = flaresolverr.fetch(api_url)
      rescue FlaresolverrService::FlaresolverrError => e
        Rails.logger.error "[Flydubai::InboundDatesService] FlareSolverr error: #{e.message}"
        return []
      end

      dates = parse_response(response, ORIGIN, DESTINATION)

      # Filter to only dates in the future
      result = dates.select { |d| d[:date] >= Date.current }
                    .uniq { |d| d[:date] }
                    .sort_by { |d| d[:date] }

      # Cache all inbound dates (not filtered by outbound date)
      if result.any?
        Rails.cache.write(self.class.cache_key, result, expires_in: CACHE_EXPIRY)
        Rails.logger.info "[Flydubai::InboundDatesService] Cached #{result.count} inbound dates"
      end

      # Return only dates after the selected outbound date
      result.select { |d| d[:date] > @date_out }
    rescue StandardError => e
      Rails.logger.error "[Flydubai::InboundDatesService] Error: #{e.message}"
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
