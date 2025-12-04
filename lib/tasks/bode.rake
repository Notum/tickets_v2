namespace :bode do
  desc "Sync Bode.lv destinations from charteri page"
  task sync_destinations: :environment do
    puts "Syncing Bode.lv destinations..."
    result = Bode::DestinationsSyncService.new.call

    if result[:success]
      puts "Success! Created: #{result[:created]}, Updated: #{result[:updated]}, Total: #{result[:total]}"
    else
      puts "Error: #{result[:error]}"
    end
  end

  desc "List all synced Bode.lv destinations"
  task list_destinations: :environment do
    destinations = BodeDestination.ordered

    if destinations.empty?
      puts "No destinations found. Run `bin/rails bode:sync_destinations` first."
    else
      puts "Bode.lv Destinations (#{destinations.count} total):"
      puts "-" * 60
      destinations.each do |d|
        puts "#{d.id.to_s.rjust(3)}. #{d.name}"
        puts "     Path: #{d.charter_path}"
        puts ""
      end
    end
  end

  desc "Fetch flights for a destination (usage: bin/rails bode:test_flights[1])"
  task :test_flights, [ :destination_id ] => :environment do |_t, args|
    destination = BodeDestination.find_by(id: args[:destination_id])

    unless destination
      puts "Destination not found. Use bin/rails bode:list_destinations to see available destinations."
      exit 1
    end

    puts "Fetching flights for: #{destination.name}"
    puts "URL: #{destination.full_url}"
    puts "-" * 60

    result = Bode::FlightsFetchService.new(destination).call

    if result[:success]
      flights = result[:flights]
      puts "Found #{flights.count} flights:"
      puts ""

      flights.first(10).each do |f|
        puts "#{f[:date_out].strftime('%d.%m.%Y')} - #{f[:date_in].strftime('%d.%m.%Y')} (#{f[:nights]}n)"
        puts "  Price: #{f[:price]}€"
        puts "  Airline: #{f[:airline] || 'N/A'}"
        puts "  Free seats: #{f[:free_seats] || 'N/A'}"
        puts "  Order URL: #{f[:order_url] || 'N/A'}"
        puts ""
      end

      if flights.count > 10
        puts "... and #{flights.count - 10} more flights"
      end
    else
      puts "Error: #{result[:error]}"
    end
  end

  desc "Test price fetch for a flight search (usage: bin/rails bode:test_price_fetch[1])"
  task :test_price_fetch, [ :search_id ] => :environment do |_t, args|
    search = BodeFlightSearch.find_by(id: args[:search_id])

    unless search
      puts "Flight search not found."
      exit 1
    end

    puts "Fetching price for flight search ##{search.id}"
    puts "Destination: #{search.bode_destination.name}"
    puts "Dates: #{search.date_out} - #{search.date_in}"
    puts "-" * 60

    result = Bode::PriceFetchService.new(search).call

    if result[:success]
      puts "Success!"
      puts "Price: #{result[:price]}€"
      puts "Status: #{search.reload.status}"
      puts "Airline: #{search.airline}"
      puts "Order URL: #{search.order_url}"

      if result[:price_drop]
        puts ""
        puts "PRICE DROP DETECTED!"
        puts "Previous: #{result[:price_drop][:previous_price]}€"
        puts "Current: #{result[:price_drop][:current_price]}€"
        puts "Savings: #{result[:price_drop][:savings]}€"
      end
    else
      puts "Error: #{result[:error]}"
    end
  end

  desc "Create a test flight search (usage: bin/rails bode:create_test_search[user@example.com,1,01.04.2026,08.04.2026])"
  task :create_test_search, [ :email, :destination_id, :date_out, :date_in ] => :environment do |_t, args|
    user = User.find_by(email: args[:email])
    unless user
      puts "User not found: #{args[:email]}"
      exit 1
    end

    destination = BodeDestination.find_by(id: args[:destination_id])
    unless destination
      puts "Destination not found: #{args[:destination_id]}"
      exit 1
    end

    # Parse dates (DD.MM.YYYY format)
    date_out_parts = args[:date_out].split(".")
    date_out = Date.new(date_out_parts[2].to_i, date_out_parts[1].to_i, date_out_parts[0].to_i)

    date_in_parts = args[:date_in].split(".")
    date_in = Date.new(date_in_parts[2].to_i, date_in_parts[1].to_i, date_in_parts[0].to_i)

    search = user.bode_flight_searches.create!(
      bode_destination: destination,
      date_out: date_out,
      date_in: date_in
    )

    puts "Created flight search ##{search.id}"
    puts "Destination: #{destination.name}"
    puts "Dates: #{date_out} - #{date_in}"
    puts ""
    puts "Fetching initial price..."

    FetchBodePriceJob.perform_now(search.id)

    search.reload
    if search.priced?
      puts "Price: #{search.price}€"
      puts "Airline: #{search.airline}"
    else
      puts "Status: #{search.status}"
    end
  end

  desc "Refresh all Bode.lv prices manually"
  task refresh_all_prices: :environment do
    puts "Refreshing all Bode.lv flight prices..."
    RefreshAllBodePricesJob.perform_now
    puts "Done!"
  end
end
