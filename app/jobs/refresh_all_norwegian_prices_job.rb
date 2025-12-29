class RefreshAllNorwegianPricesJob < ApplicationJob
  queue_as :default

  def perform
    flight_searches = NorwegianFlightSearch.where(status: "priced").or(NorwegianFlightSearch.where(status: "error"))

    Rails.logger.info "[RefreshAllNorwegianPricesJob] Refreshing prices for #{flight_searches.count} flight searches"

    # Collect price drops grouped by user
    price_drops_by_user = Hash.new { |h, k| h[k] = [] }

    flight_searches.find_each do |search|
      # Skip if flight dates are in the past
      if search.date_out < Date.current
        Rails.logger.info "[RefreshAllNorwegianPricesJob] Skipping flight search ##{search.id} - departure date is in the past"
        next
      end

      # Process synchronously to collect price drops
      result = Norwegian::PriceFetchService.new(search).call

      if result[:success] && result[:price_drop].present?
        user = search.user
        # Only include if price drop exceeds user's threshold
        if result[:price_drop][:savings] >= user.price_notification_threshold
          price_drops_by_user[user.id] << result[:price_drop]
          Rails.logger.info "[RefreshAllNorwegianPricesJob] Price drop detected for user #{user.id}: #{result[:price_drop][:savings]} EUR"
        else
          Rails.logger.info "[RefreshAllNorwegianPricesJob] Price drop of #{result[:price_drop][:savings]} EUR below threshold for user #{user.id}"
        end
      end
    end

    # Send notification emails per user
    price_drops_by_user.each do |user_id, price_drops|
      next if price_drops.empty?

      user = User.find(user_id)
      Rails.logger.info "[RefreshAllNorwegianPricesJob] Sending price drop notification to #{user.email} with #{price_drops.count} drops"
      NorwegianPriceDropMailer.price_dropped(user, price_drops).deliver_later
    end

    Rails.logger.info "[RefreshAllNorwegianPricesJob] Completed price refresh. Sent notifications to #{price_drops_by_user.keys.count} users"
  end
end
