require "net/http"
require "json"

module Norwegian
  class InboundDatesService
    FARE_CALENDAR_API = "https://www.norwegian.com/api/fare-calendar/calendar".freeze
    CACHE_EXPIRY = 1.week

    def self.cache_key(destination_code)
      "norwegian_inbound_dates_#{destination_code}"
    end

    def initialize(destination_code, date_out)
      @destination_code = destination_code
      @date_out = date_out.is_a?(Date) ? date_out : Date.parse(date_out)
    end

    def call
      # Check cache first for fast response
      cached_dates = Rails.cache.read(self.class.cache_key(@destination_code))
      if cached_dates.present?
        # Filter cached dates to only show dates after the selected outbound date
        filtered = cached_dates.select { |d| d[:date] > @date_out }
        Rails.logger.info "[Norwegian::InboundDatesService] Returning #{filtered.count} cached inbound dates for #{@destination_code} (after #{@date_out})"
        return filtered
      end

      Rails.logger.info "[Norwegian::InboundDatesService] Cache miss, fetching inbound dates for #{@destination_code} from #{@date_out}"

      flaresolverr = FlaresolverrService.new

      # Fetch fare calendar for the next ~12 months from date_out
      all_dates = []
      current_month = @date_out.beginning_of_month

      # Fetch 12 months of data
      12.times do |i|
        month_start = current_month + i.months
        api_url = build_calendar_url(month_start)

        begin
          response = flaresolverr.fetch(api_url)
        rescue FlaresolverrService::FlaresolverrError => e
          Rails.logger.error "[Norwegian::InboundDatesService] FlareSolverr error: #{e.message}"
          next
        end

        if response.is_a?(Hash) && response["inbound"] && response["inbound"]["days"]
          dates = parse_inbound_dates(response["inbound"]["days"])
          all_dates.concat(dates)
        end

        sleep 1 # Be polite between requests
      end

      # Filter to only dates in the future
      result = all_dates.select { |d| d[:date] >= Date.current }
                        .uniq { |d| d[:date] }
                        .sort_by { |d| d[:date] }

      # Cache all inbound dates (not filtered by outbound date)
      if result.any?
        Rails.cache.write(self.class.cache_key(@destination_code), result, expires_in: CACHE_EXPIRY)
        Rails.logger.info "[Norwegian::InboundDatesService] Cached #{result.count} inbound dates for #{@destination_code}"
      end

      # Return only dates after the selected outbound date
      result.select { |d| d[:date] > @date_out }
    rescue StandardError => e
      Rails.logger.error "[Norwegian::InboundDatesService] Error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      []
    end

    private

    def build_calendar_url(month_start)
      params = {
        "adultCount" => "1",
        "destinationAirportCode" => @destination_code,
        "originAirportCode" => "RIX",
        "outboundDate" => month_start.strftime("%Y-%m-%d"),
        "inboundDate" => month_start.strftime("%Y-%m-%d"),
        "tripType" => "2",
        "currencyCode" => "EUR",
        "languageCode" => "en-BZ",
        "pageId" => "258774",
        "eventType" => "init"
      }

      uri = URI(FARE_CALENDAR_API)
      uri.query = URI.encode_www_form(params)
      uri.to_s
    end

    def parse_inbound_dates(days)
      days.map do |day|
        date_str = day["date"]
        next unless date_str.present?

        # Parse date from format "2026-10-03T00:00:00"
        date = Date.parse(date_str.split("T").first)
        price = day["price"].to_f
        transit_count = day["transitCount"].to_i

        # Only include dates with available flights (price > 0)
        next unless price > 0

        {
          date: date,
          is_direct: transit_count == 0
        }
      end.compact
    end
  end
end
