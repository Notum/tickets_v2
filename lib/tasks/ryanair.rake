namespace :ryanair do
  desc "Sync Ryanair destinations from RIX airport"
  task sync_routes: :environment do
    puts "Syncing Ryanair routes from RIX..."

    result = Ryanair::RoutesSyncService.new.call

    if result[:success]
      puts "Sync completed successfully!"
      puts "  Created: #{result[:created]}"
      puts "  Updated: #{result[:updated]}"
      puts "  Total: #{result[:total]}"
    else
      puts "Sync failed: #{result[:error]}"
      exit 1
    end
  end

  desc "Test outbound dates for a destination. Usage: bin/rails ryanair:test_dates_out[DUB]"
  task :test_dates_out, [ :destination_code ] => :environment do |t, args|
    destination_code = args[:destination_code]

    if destination_code.blank?
      puts "Error: Destination code is required"
      puts "Usage: bin/rails ryanair:test_dates_out[DUB]"
      exit 1
    end

    puts "Fetching outbound dates from RIX to #{destination_code}..."

    dates = Ryanair::OutboundDatesService.new(destination_code).call

    if dates.empty?
      puts "No available dates found."
    else
      puts "Available outbound dates (#{dates.count}):"
      dates.each do |date|
        puts "  #{date.strftime('%Y-%m-%d (%A)')}"
      end
    end
  end

  desc "Test return dates for a destination. Usage: bin/rails ryanair:test_dates_in[DUB]"
  task :test_dates_in, [ :destination_code ] => :environment do |t, args|
    destination_code = args[:destination_code]

    if destination_code.blank?
      puts "Error: Destination code is required"
      puts "Usage: bin/rails ryanair:test_dates_in[DUB]"
      exit 1
    end

    puts "Fetching return dates from #{destination_code} to RIX..."

    dates = Ryanair::ReturnDatesService.new(destination_code).call

    if dates.empty?
      puts "No available dates found."
    else
      puts "Available return dates (#{dates.count}):"
      dates.each do |date|
        puts "  #{date.strftime('%Y-%m-%d (%A)')}"
      end
    end
  end

  desc "Test price fetch for a saved flight search. Usage: bin/rails ryanair:test_price_fetch[1]"
  task :test_price_fetch, [ :flight_search_id ] => :environment do |t, args|
    flight_search_id = args[:flight_search_id]

    if flight_search_id.blank?
      puts "Error: Flight search ID is required"
      puts "Usage: bin/rails ryanair:test_price_fetch[1]"
      exit 1
    end

    flight_search = RyanairFlightSearch.find_by(id: flight_search_id)

    unless flight_search
      puts "Error: Flight search ##{flight_search_id} not found"
      exit 1
    end

    puts "Testing price fetch for flight search ##{flight_search.id}:"
    puts "  Destination: #{flight_search.ryanair_destination.name} (#{flight_search.ryanair_destination.code})"
    puts "  Date Out: #{flight_search.date_out}"
    puts "  Date In: #{flight_search.date_in}"
    puts ""

    puts "Fetching prices (this may take a moment due to headless browser)..."

    result = Ryanair::PriceFetchService.new(flight_search).call

    puts ""
    if result[:success]
      flight_search.reload
      puts "Prices fetched successfully!"
      puts "  Price Out: #{flight_search.price_out}"
      puts "  Price In: #{flight_search.price_in}"
      puts "  Total: #{flight_search.total_price}"
      puts "  Status: #{flight_search.status}"
    else
      puts "Failed to fetch prices: #{result[:error]}"
    end
  end

  desc "List all Ryanair destinations"
  task list_destinations: :environment do
    destinations = RyanairDestination.order(:name)

    if destinations.empty?
      puts "No destinations found. Run 'bin/rails ryanair:sync_routes' first."
    else
      puts "Ryanair destinations from RIX (#{destinations.count}):"
      destinations.each do |dest|
        puts "  [#{dest.code}] #{dest.name}, #{dest.country_name}"
      end
    end
  end

  desc "Create a test flight search. Usage: bin/rails ryanair:create_test_search[user@example.com,DUB,2025-12-21,2025-12-28]"
  task :create_test_search, [ :email, :destination_code, :date_out, :date_in ] => :environment do |t, args|
    email = args[:email]
    destination_code = args[:destination_code]
    date_out = args[:date_out]
    date_in = args[:date_in]

    if email.blank? || destination_code.blank? || date_out.blank? || date_in.blank?
      puts "Error: All parameters are required"
      puts "Usage: bin/rails ryanair:create_test_search[user@example.com,DUB,2025-12-21,2025-12-28]"
      exit 1
    end

    user = User.find_by("LOWER(email) = ?", email.downcase)
    unless user
      puts "Error: User not found: #{email}"
      exit 1
    end

    destination = RyanairDestination.find_by(code: destination_code.upcase)
    unless destination
      puts "Error: Destination not found: #{destination_code}"
      puts "Run 'bin/rails ryanair:sync_routes' to fetch destinations."
      exit 1
    end

    flight_search = RyanairFlightSearch.create!(
      user: user,
      ryanair_destination: destination,
      date_out: Date.parse(date_out),
      date_in: Date.parse(date_in)
    )

    puts "Flight search created successfully!"
    puts "  ID: #{flight_search.id}"
    puts "  User: #{user.email}"
    puts "  Destination: #{destination.name} (#{destination.code})"
    puts "  Date Out: #{flight_search.date_out}"
    puts "  Date In: #{flight_search.date_in}"
    puts ""
    puts "To fetch prices, run: bin/rails ryanair:test_price_fetch[#{flight_search.id}]"
  end
end
