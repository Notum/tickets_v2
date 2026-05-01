class RefreshAllRyanairPricesJob < ApplicationJob
  queue_as :default

  # A search is destroyed after this many consecutive cycles of returning no fares
  UNAVAILABLE_STRIKES_LIMIT = 3

  def perform
    flight_searches = RyanairFlightSearch.where(status: %w[priced error unavailable])

    Rails.logger.info "[RefreshAllRyanairPricesJob] Refreshing prices for #{flight_searches.count} flight searches"

    # Collect price drops grouped by user
    price_drops_by_user = Hash.new { |h, k| h[k] = [] }
    # Collect failures for admin notification
    failures = []

    flight_searches.find_each do |search|
      # Skip if departure is today or earlier (flights disappear the day before departure)
      if search.date_out <= Date.current + 1.day
        Rails.logger.info "[RefreshAllRyanairPricesJob] Skipping flight search ##{search.id} - departure within one day"
        next
      end

      # Process synchronously to collect price drops
      result = Ryanair::PriceFetchService.new(search).call

      if result[:success]
        if result[:price_drop].present?
          user = search.user
          # Only include if price drop exceeds user's threshold
          if result[:price_drop][:savings] >= user.price_notification_threshold
            price_drops_by_user[user.id] << result[:price_drop]
            Rails.logger.info "[RefreshAllRyanairPricesJob] Price drop detected for user #{user.id}: #{result[:price_drop][:savings]} EUR"
          else
            Rails.logger.info "[RefreshAllRyanairPricesJob] Price drop of #{result[:price_drop][:savings]} EUR below threshold for user #{user.id}"
          end
        end
      elsif result[:unavailable]
        handle_unavailable(search)
      else
        # Track failure for admin notification
        failures << {
          flight_search_id: search.id,
          destination: search.ryanair_destination&.code,
          dates: "#{search.date_out.strftime('%d %b')} - #{search.date_in.strftime('%d %b %Y')}",
          error: result[:error] || "Unknown error"
        }
        Rails.logger.error "[RefreshAllRyanairPricesJob] Failed to fetch price for search ##{search.id}: #{result[:error]}"
      end
    end

    # Send notification emails per user
    price_drops_by_user.each do |user_id, price_drops|
      next if price_drops.empty?

      user = User.find(user_id)
      Rails.logger.info "[RefreshAllRyanairPricesJob] Sending price drop notification to #{user.email} with #{price_drops.count} drops"
      RyanairPriceDropMailer.price_dropped(user, price_drops).deliver_later
    end

    # Send failure notification to admin if there were any failures
    if failures.any?
      Rails.logger.warn "[RefreshAllRyanairPricesJob] Sending failure notification for #{failures.count} failed fetches"
      FetchFailureMailer.fetch_failed(airline: "Ryanair", failures: failures).deliver_later
    end

    Rails.logger.info "[RefreshAllRyanairPricesJob] Completed price refresh. Sent notifications to #{price_drops_by_user.keys.count} users. Failures: #{failures.count}"
  end

  private

  def handle_unavailable(search)
    strikes = search.unavailable_strikes + 1

    if strikes >= UNAVAILABLE_STRIKES_LIMIT
      Rails.logger.info "[RefreshAllRyanairPricesJob] Destroying search ##{search.id} (#{search.ryanair_destination&.code} #{search.date_out} - #{search.date_in}) — unavailable for #{strikes} consecutive cycles"
      search.destroy!
    else
      search.update!(unavailable_strikes: strikes)
      Rails.logger.info "[RefreshAllRyanairPricesJob] Search ##{search.id} unavailable (strike #{strikes}/#{UNAVAILABLE_STRIKES_LIMIT})"
    end
  end
end
