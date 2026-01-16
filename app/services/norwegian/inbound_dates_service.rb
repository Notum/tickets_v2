module Norwegian
  class InboundDatesService
    def self.cache_key(destination_code)
      "norwegian_inbound_dates_#{destination_code}"
    end

    def initialize(destination_code, date_out)
      @destination_code = destination_code
      @date_out = date_out.is_a?(Date) ? date_out : Date.parse(date_out)
    end

    def call
      # Check cache first - dates are prefetched by background job
      cached_dates = Rails.cache.read(self.class.cache_key(@destination_code))
      if cached_dates.present?
        # Filter cached dates to only show dates after the selected outbound date
        filtered = cached_dates.select { |d| d[:date] > @date_out }
        Rails.logger.info "[Norwegian::InboundDatesService] Returning #{filtered.count} cached inbound dates for #{@destination_code} (after #{@date_out})"
        return filtered
      end

      # Cache miss - return empty array, dates will be populated by PrefetchNorwegianDatesJob
      # We don't fetch synchronously to avoid timeout issues with FlareSolverr
      Rails.logger.info "[Norwegian::InboundDatesService] Cache miss for #{@destination_code}, returning empty (dates fetched by background job)"
      []
    end
  end
end
