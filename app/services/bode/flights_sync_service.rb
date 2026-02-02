module Bode
  class FlightsSyncService
    def call
      Rails.logger.info "[Bode::FlightsSyncService] Starting flights sync"

      destinations = BodeDestination.active
      total_flights = 0
      total_created = 0
      total_updated = 0
      price_drops_by_user = Hash.new { |h, k| h[k] = [] }
      failures = []

      destinations.find_each do |destination|
        result = sync_destination(destination, price_drops_by_user)

        if result[:success]
          total_flights += result[:flight_count]
          total_created += result[:created]
          total_updated += result[:updated]
        else
          failures << { destination: destination.name, error: result[:error] }
        end
      end

      # Mark stale flights and their linked searches
      mark_stale_flights

      # Send price drop notifications
      send_price_drop_notifications(price_drops_by_user)

      # Send failure notification if needed
      if failures.any?
        Rails.logger.warn "[Bode::FlightsSyncService] #{failures.count} destination(s) failed"
        FetchFailureMailer.fetch_failed(airline: "Bode.lv", failures: failures).deliver_later
      end

      Rails.logger.info "[Bode::FlightsSyncService] Completed: #{total_flights} flights (#{total_created} new, #{total_updated} updated) across #{destinations.count} destinations"
      { success: true, flights: total_flights, created: total_created, updated: total_updated, failures: failures.count }
    rescue StandardError => e
      Rails.logger.error "[Bode::FlightsSyncService] Error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      { success: false, error: e.message }
    end

    private

    def sync_destination(destination, price_drops_by_user)
      Rails.logger.info "[Bode::FlightsSyncService] Syncing #{destination.name}"

      result = FlightsFetchService.new(destination).call

      unless result[:success]
        Rails.logger.error "[Bode::FlightsSyncService] Failed to fetch flights for #{destination.name}: #{result[:error]}"
        return { success: false, error: result[:error] }
      end

      created = 0
      updated = 0

      result[:flights].each do |flight_data|
        bode_flight = BodeFlight.find_or_initialize_by(
          bode_destination: destination,
          date_out: flight_data[:date_out],
          date_in: flight_data[:date_in]
        )

        is_new = bode_flight.new_record?
        previous_price = bode_flight.price

        bode_flight.assign_attributes(
          nights: flight_data[:nights],
          price: flight_data[:price],
          airline: flight_data[:airline],
          order_url: flight_data[:order_url],
          free_seats: flight_data[:free_seats],
          last_seen_at: Time.current
        )

        bode_flight.save!

        # Record price history when price changes
        bode_flight.record_price_if_changed(flight_data[:price])

        if is_new
          created += 1
        else
          updated += 1
        end

        # Update linked flight searches
        update_linked_searches(bode_flight, previous_price, price_drops_by_user)
      end

      { success: true, flight_count: result[:flights].count, created: created, updated: updated }
    rescue StandardError => e
      Rails.logger.error "[Bode::FlightsSyncService] Error syncing #{destination.name}: #{e.message}"
      { success: false, error: e.message }
    end

    def update_linked_searches(bode_flight, previous_price, price_drops_by_user)
      bode_flight.bode_flight_searches.where(status: %w[pending priced error unavailable]).find_each do |search|
        search_previous_price = search.price
        new_price = bode_flight.price

        search.update!(
          price: new_price,
          airline: bode_flight.airline,
          order_url: bode_flight.order_url,
          free_seats: bode_flight.free_seats,
          nights: bode_flight.nights,
          status: "priced",
          priced_at: Time.current
        )

        # Record price history on the search's own history too
        search.record_price_if_changed(new_price)

        # Detect price drop
        if search_previous_price.present? && new_price < search_previous_price
          savings = search_previous_price - new_price
          user = search.user

          if savings >= user.price_notification_threshold
            price_drops_by_user[user.id] << {
              flight_search_id: search.id,
              destination_name: search.bode_destination.name,
              date_out: search.date_out,
              date_in: search.date_in,
              previous_price: search_previous_price,
              current_price: new_price,
              savings: savings,
              order_url: search.order_url
            }
          end
        end
      end
    end

    def mark_stale_flights
      # Flights not seen in the last sync cycle (>2 hours) are considered stale
      stale_flights = BodeFlight.where("last_seen_at < ?", 2.hours.ago).where("date_out >= ?", Date.current)

      stale_flights.find_each do |flight|
        flight.bode_flight_searches.where(status: %w[pending priced]).find_each do |search|
          search.update!(status: "unavailable")
          Rails.logger.info "[Bode::FlightsSyncService] Marked search ##{search.id} as unavailable (flight not seen recently)"
        end
      end
    end

    def send_price_drop_notifications(price_drops_by_user)
      price_drops_by_user.each do |user_id, price_drops|
        next if price_drops.empty?

        user = User.find(user_id)
        Rails.logger.info "[Bode::FlightsSyncService] Sending price drop notification to #{user.email} with #{price_drops.count} drops"
        BodePriceDropMailer.price_dropped(user, price_drops).deliver_later
      end
    end
  end
end
