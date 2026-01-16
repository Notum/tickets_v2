module Norwegian
  class OutboundDatesService
    # API URL kept for use by PrefetchNorwegianDatesJob
    FARE_CALENDAR_API = "https://www.norwegian.com/api/fare-calendar/calendar".freeze

    def self.cache_key(destination_code)
      "norwegian_outbound_dates_#{destination_code}"
    end

    def initialize(destination_code)
      @destination_code = destination_code
    end

    def call
      # Check cache first - dates are prefetched by background job
      cached_dates = Rails.cache.read(self.class.cache_key(@destination_code))
      if cached_dates.present?
        Rails.logger.info "[Norwegian::OutboundDatesService] Returning #{cached_dates.count} cached dates for #{@destination_code}"
        return cached_dates
      end

      # Cache miss - return empty array, dates will be populated by PrefetchNorwegianDatesJob
      # We don't fetch synchronously to avoid timeout issues with FlareSolverr
      Rails.logger.info "[Norwegian::OutboundDatesService] Cache miss for #{@destination_code}, returning empty (dates fetched by background job)"
      []
    end
  end
end
