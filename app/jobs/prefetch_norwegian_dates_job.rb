class PrefetchNorwegianDatesJob < ApplicationJob
  queue_as :default

  # Cache expiration: 1 week (job runs weekly on its own schedule)
  CACHE_EXPIRY = 1.week

  def perform
    Rails.logger.info "[PrefetchNorwegianDatesJob] Starting to prefetch dates for all Norwegian destinations..."

    destinations = NorwegianDestination.active
    total = destinations.count
    prefetched = 0
    failed = 0

    flaresolverr = FlaresolverrService.new

    destinations.find_each.with_index do |destination, index|
      Rails.logger.info "[PrefetchNorwegianDatesJob] Prefetching dates for #{destination.code} (#{index + 1}/#{total})"

      begin
        result = fetch_all_dates(destination.code, flaresolverr)

        # Cache outbound dates
        if result[:outbound].any?
          outbound_cache_key = Norwegian::OutboundDatesService.cache_key(destination.code)
          Rails.cache.write(outbound_cache_key, result[:outbound], expires_in: CACHE_EXPIRY)
          Rails.logger.info "[PrefetchNorwegianDatesJob] Cached #{result[:outbound].count} outbound dates for #{destination.code}"
        end

        # Cache inbound dates
        if result[:inbound].any?
          inbound_cache_key = Norwegian::InboundDatesService.cache_key(destination.code)
          Rails.cache.write(inbound_cache_key, result[:inbound], expires_in: CACHE_EXPIRY)
          Rails.logger.info "[PrefetchNorwegianDatesJob] Cached #{result[:inbound].count} inbound dates for #{destination.code}"
        end

        if result[:outbound].any? || result[:inbound].any?
          prefetched += 1
        else
          failed += 1
          Rails.logger.warn "[PrefetchNorwegianDatesJob] No dates found for #{destination.code}"
        end
      rescue StandardError => e
        failed += 1
        Rails.logger.error "[PrefetchNorwegianDatesJob] Error fetching dates for #{destination.code}: #{e.message}"
      end

      # Be polite between destinations
      sleep 2
    end

    Rails.logger.info "[PrefetchNorwegianDatesJob] Completed: #{prefetched} prefetched, #{failed} failed out of #{total}"

    { prefetched: prefetched, failed: failed, total: total }
  end

  private

  def fetch_all_dates(destination_code, flaresolverr)
    all_outbound = []
    all_inbound = []
    current_date = Date.current

    # Fetch 13 months of data to ensure full year coverage from today
    # (e.g., if today is Jan 16, we need Jan-Jan next year to cover 12 months ahead)
    13.times do |i|
      month_start = current_date.beginning_of_month + i.months
      api_url = build_calendar_url(destination_code, month_start)

      begin
        response = flaresolverr.fetch(api_url)
      rescue FlaresolverrService::FlaresolverrError => e
        Rails.logger.error "[PrefetchNorwegianDatesJob] FlareSolverr error for #{destination_code}: #{e.message}"
        next
      end

      if response.is_a?(Hash)
        # Extract outbound dates
        if response["outbound"] && response["outbound"]["days"]
          dates = parse_dates(response["outbound"]["days"])
          all_outbound.concat(dates)
        end

        # Extract inbound dates from the SAME response
        if response["inbound"] && response["inbound"]["days"]
          dates = parse_dates(response["inbound"]["days"])
          all_inbound.concat(dates)
        end
      end

      sleep 1 # Be polite between requests
    end

    # Filter and deduplicate
    {
      outbound: filter_and_sort_dates(all_outbound),
      inbound: filter_and_sort_dates(all_inbound)
    }
  end

  def build_calendar_url(destination_code, month_start)
    params = {
      "adultCount" => "1",
      "destinationAirportCode" => destination_code,
      "originAirportCode" => "RIX",
      "outboundDate" => month_start.strftime("%Y-%m-%d"),
      "inboundDate" => month_start.strftime("%Y-%m-%d"),
      "tripType" => "2",
      "currencyCode" => "EUR",
      "languageCode" => "en-BZ",
      "pageId" => "258774",
      "eventType" => "init"
    }

    uri = URI(Norwegian::OutboundDatesService::FARE_CALENDAR_API)
    uri.query = URI.encode_www_form(params)
    uri.to_s
  end

  def parse_dates(days)
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

  def filter_and_sort_dates(dates)
    dates.select { |d| d[:date] >= Date.current }
         .uniq { |d| d[:date] }
         .sort_by { |d| d[:date] }
  end
end
