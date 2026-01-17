class RefreshAllBookingPricesJob < ApplicationJob
  queue_as :default

  def perform
    searches = BookingSearch.where(status: %w[priced error sold_out])

    Rails.logger.info "[RefreshAllBookingPricesJob] Refreshing prices for #{searches.count} hotel searches"

    price_drops_by_user = Hash.new { |h, k| h[k] = [] }
    failures = []

    searches.find_each do |search|
      # Skip if check-in date is in the past
      if search.check_in < Date.current
        Rails.logger.info "[RefreshAllBookingPricesJob] Skipping search ##{search.id} - check-in date is in the past"
        next
      end

      result = Booking::PriceFetchService.new(search).call

      if result[:success]
        if result[:price_drop].present?
          user = search.user
          if result[:price_drop][:savings] >= user.price_notification_threshold
            price_drops_by_user[user.id] << result[:price_drop]
            Rails.logger.info "[RefreshAllBookingPricesJob] Price drop detected for user #{user.id}: #{result[:price_drop][:savings]} #{search.currency}"
          else
            Rails.logger.info "[RefreshAllBookingPricesJob] Price drop of #{result[:price_drop][:savings]} #{search.currency} below threshold for user #{user.id}"
          end
        end
      else
        failures << {
          booking_search_id: search.id,
          hotel_name: search.hotel_name,
          dates: "#{search.check_in.strftime('%d %b')} - #{search.check_out.strftime('%d %b %Y')}",
          error: result[:error] || "Unknown error"
        }
        Rails.logger.error "[RefreshAllBookingPricesJob] Failed to fetch price for search ##{search.id}: #{result[:error]}"
      end

      # Add delay between requests to avoid rate limiting
      sleep(2)
    end

    # Send notification emails per user
    price_drops_by_user.each do |user_id, price_drops|
      next if price_drops.empty?

      user = User.find(user_id)
      Rails.logger.info "[RefreshAllBookingPricesJob] Sending price drop notification to #{user.email} with #{price_drops.count} drops"
      BookingPriceDropMailer.price_dropped(user, price_drops).deliver_later
    end

    # Send failure notification to admin if there were any failures
    if failures.any?
      Rails.logger.warn "[RefreshAllBookingPricesJob] Sending failure notification for #{failures.count} failed fetches"
      FetchFailureMailer.fetch_failed(airline: "Booking.com", failures: failures).deliver_later
    end

    Rails.logger.info "[RefreshAllBookingPricesJob] Completed price refresh. Sent notifications to #{price_drops_by_user.keys.count} users. Failures: #{failures.count}"
  end
end
