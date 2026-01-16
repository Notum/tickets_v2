class PrefetchNorwegianDatesJob < ApplicationJob
  queue_as :default

  # Cache expiration: 1 week (job runs weekly on its own schedule)
  CACHE_EXPIRY = 1.week

  # Number of concurrent threads for fetching destinations
  # Keep low (2) since each thread maintains a FlareSolverr browser session
  THREAD_POOL_SIZE = 2

  def perform
    Rails.logger.info "[PrefetchNorwegianDatesJob] Starting to prefetch dates for all Norwegian destinations..."

    destinations = NorwegianDestination.active.to_a
    total = destinations.count

    # Thread-safe counters
    prefetched = Concurrent::AtomicFixnum.new(0)
    failed = Concurrent::AtomicFixnum.new(0)
    processed = Concurrent::AtomicFixnum.new(0)

    # Create a thread pool with limited concurrency
    pool = Concurrent::FixedThreadPool.new(THREAD_POOL_SIZE)

    # Submit tasks for each destination
    futures = destinations.map do |destination|
      Concurrent::Future.execute(executor: pool) do
        fetch_and_cache_destination(destination, prefetched, failed, processed, total)
      end
    end

    # Wait for all tasks to complete
    futures.each(&:wait)

    # Shutdown the thread pool
    pool.shutdown
    pool.wait_for_termination

    Rails.logger.info "[PrefetchNorwegianDatesJob] Completed: #{prefetched.value} prefetched, #{failed.value} failed out of #{total}"

    { prefetched: prefetched.value, failed: failed.value, total: total }
  end

  private

  def fetch_and_cache_destination(destination, prefetched, failed, processed, total)
    current = processed.increment
    Rails.logger.info "[PrefetchNorwegianDatesJob] Prefetching dates for #{destination.code} (#{current}/#{total})"

    # Each thread gets its own FlareSolverr instance
    flaresolverr = FlaresolverrService.new
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
      prefetched.increment
    else
      failed.increment
      Rails.logger.warn "[PrefetchNorwegianDatesJob] No dates found for #{destination.code}"
    end
  rescue StandardError => e
    failed.increment
    Rails.logger.error "[PrefetchNorwegianDatesJob] Error fetching dates for #{destination.code}: #{e.message}"
  end

  def fetch_all_dates(destination_code, flaresolverr)
    all_outbound = []
    all_inbound = []
    current_date = Date.current
    session_id = nil

    begin
      # Create a session to maintain cookies across all month requests
      session_id = flaresolverr.create_session
      Rails.logger.info "[PrefetchNorwegianDatesJob] Created session #{session_id} for #{destination_code}"

      # First request establishes the session/cookies
      first_url = build_calendar_url(destination_code, current_date.beginning_of_month)
      flaresolverr.get_with_session(first_url, session_id)
      sleep 1

      # Fetch 13 months of data to ensure full year coverage from today
      13.times do |i|
        month_start = current_date.beginning_of_month + i.months
        api_url = build_calendar_url(destination_code, month_start)

        response = fetch_with_retry(flaresolverr, api_url, session_id, destination_code)

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
    ensure
      # Always destroy the session
      flaresolverr.destroy_session(session_id) if session_id
    end

    # Filter and deduplicate
    {
      outbound: filter_and_sort_dates(all_outbound),
      inbound: filter_and_sort_dates(all_inbound)
    }
  end

  def fetch_with_retry(flaresolverr, url, session_id, destination_code, max_retries: 2)
    retries = 0

    loop do
      begin
        response = flaresolverr.get_with_session(url, session_id)

        # Check if we got a valid response (Hash with data) or a small invalid response
        if response.is_a?(Hash) && (response["outbound"] || response["inbound"])
          return response
        elsif response.is_a?(String) && response.length < 100
          # Small response likely means challenge failed or no data
          Rails.logger.warn "[PrefetchNorwegianDatesJob] Small response (#{response.length} bytes) for #{destination_code}: #{response.first(100)}"

          if retries < max_retries
            retries += 1
            Rails.logger.info "[PrefetchNorwegianDatesJob] Retrying #{url} (attempt #{retries + 1}/#{max_retries + 1})"
            sleep 2
            next
          end
        end

        return response
      rescue FlaresolverrService::FlaresolverrError => e
        Rails.logger.error "[PrefetchNorwegianDatesJob] FlareSolverr error for #{destination_code}: #{e.message}"

        if retries < max_retries
          retries += 1
          Rails.logger.info "[PrefetchNorwegianDatesJob] Retrying after error (attempt #{retries + 1}/#{max_retries + 1})"
          sleep 2
          next
        end

        return nil
      end
    end
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
