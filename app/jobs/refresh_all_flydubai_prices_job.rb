class RefreshAllFlydubaiPricesJob < ApplicationJob
  queue_as :default

  def perform
    flight_searches = FlydubaiFlightSearch.where(status: "priced").or(FlydubaiFlightSearch.where(status: "error"))

    Rails.logger.info "[RefreshAllFlydubaiPricesJob] Refreshing prices for #{flight_searches.count} flight searches"

    # Collect price drops grouped by user
    price_drops_by_user = Hash.new { |h, k| h[k] = [] }
    # Collect failures for admin notification
    failures = []

    flight_searches.find_each do |search|
      # Skip if flight dates are in the past
      if search.date_out < Date.current
        Rails.logger.info "[RefreshAllFlydubaiPricesJob] Skipping flight search ##{search.id} - departure date is in the past"
        next
      end

      # Process synchronously to collect price drops
      result = Flydubai::PriceFetchService.new(search).call

      if result[:success]
        if result[:price_drop].present?
          user = search.user
          # Only include if price drop exceeds user's threshold
          if result[:price_drop][:savings] >= user.price_notification_threshold
            price_drops_by_user[user.id] << result[:price_drop]
            Rails.logger.info "[RefreshAllFlydubaiPricesJob] Price drop detected for user #{user.id}: #{result[:price_drop][:savings]}"
          else
            Rails.logger.info "[RefreshAllFlydubaiPricesJob] Price drop of #{result[:price_drop][:savings]} below threshold for user #{user.id}"
          end
        end
      else
        # Track failure for admin notification
        failures << {
          flight_search_id: search.id,
          destination: FlydubaiFlightSearch::DESTINATION,
          dates: "#{search.date_out.strftime('%d %b')} - #{search.date_in.strftime('%d %b %Y')}",
          error: result[:error] || "Unknown error"
        }
        Rails.logger.error "[RefreshAllFlydubaiPricesJob] Failed to fetch price for search ##{search.id}: #{result[:error]}"
      end
    end

    # Send notification emails per user
    price_drops_by_user.each do |user_id, price_drops|
      next if price_drops.empty?

      user = User.find(user_id)
      Rails.logger.info "[RefreshAllFlydubaiPricesJob] Sending price drop notification to #{user.email} with #{price_drops.count} drops"
      FlydubaiPriceDropMailer.price_dropped(user, price_drops).deliver_later
    end

    # Send failure notification to admin if there were any failures
    if failures.any?
      Rails.logger.warn "[RefreshAllFlydubaiPricesJob] Sending failure notification for #{failures.count} failed fetches"
      FetchFailureMailer.fetch_failed(airline: "FlyDubai", failures: failures).deliver_later
    end

    Rails.logger.info "[RefreshAllFlydubaiPricesJob] Completed price refresh. Sent notifications to #{price_drops_by_user.keys.count} users. Failures: #{failures.count}"
  end
end
