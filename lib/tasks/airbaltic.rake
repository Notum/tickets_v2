namespace :airbaltic do
  desc "Sync AirBaltic destinations from TripX API"
  task sync_destinations: :environment do
    puts "Syncing AirBaltic destinations from TripX API..."
    result = Airbaltic::DestinationsSyncService.new.call

    if result[:success]
      puts "Sync completed: #{result[:created]} created, #{result[:updated]} updated, #{result[:deactivated]} deactivated, #{result[:total]} total"
    else
      puts "Sync failed: #{result[:error]}"
      exit 1
    end
  end

  desc "Seed AirBaltic destinations from RIX (legacy - use sync_destinations instead)"
  task seed_destinations: :environment do
    destinations = [
      # Baltic States
      { code: "TLL", name: "Tallinn", city_name: "Tallinn", country_name: "Estonia", country_code: "EE" },
      { code: "VNO", name: "Vilnius", city_name: "Vilnius", country_name: "Lithuania", country_code: "LT" },

      # Nordic Countries
      { code: "HEL", name: "Helsinki", city_name: "Helsinki", country_name: "Finland", country_code: "FI" },
      { code: "ARN", name: "Stockholm Arlanda", city_name: "Stockholm", country_name: "Sweden", country_code: "SE" },
      { code: "CPH", name: "Copenhagen", city_name: "Copenhagen", country_name: "Denmark", country_code: "DK" },
      { code: "OSL", name: "Oslo Gardermoen", city_name: "Oslo", country_name: "Norway", country_code: "NO" },

      # Western Europe
      { code: "AMS", name: "Amsterdam", city_name: "Amsterdam", country_name: "Netherlands", country_code: "NL" },
      { code: "BRU", name: "Brussels", city_name: "Brussels", country_name: "Belgium", country_code: "BE" },
      { code: "CDG", name: "Paris Charles de Gaulle", city_name: "Paris", country_name: "France", country_code: "FR" },
      { code: "LHR", name: "London Heathrow", city_name: "London", country_name: "United Kingdom", country_code: "GB" },
      { code: "DUB", name: "Dublin", city_name: "Dublin", country_name: "Ireland", country_code: "IE" },

      # Central Europe
      { code: "FRA", name: "Frankfurt", city_name: "Frankfurt", country_name: "Germany", country_code: "DE" },
      { code: "MUC", name: "Munich", city_name: "Munich", country_name: "Germany", country_code: "DE" },
      { code: "BER", name: "Berlin Brandenburg", city_name: "Berlin", country_name: "Germany", country_code: "DE" },
      { code: "HAM", name: "Hamburg", city_name: "Hamburg", country_name: "Germany", country_code: "DE" },
      { code: "DUS", name: "Dusseldorf", city_name: "Dusseldorf", country_name: "Germany", country_code: "DE" },
      { code: "VIE", name: "Vienna", city_name: "Vienna", country_name: "Austria", country_code: "AT" },
      { code: "ZRH", name: "Zurich", city_name: "Zurich", country_name: "Switzerland", country_code: "CH" },
      { code: "GVA", name: "Geneva", city_name: "Geneva", country_name: "Switzerland", country_code: "CH" },
      { code: "WAW", name: "Warsaw Chopin", city_name: "Warsaw", country_name: "Poland", country_code: "PL" },
      { code: "PRG", name: "Prague", city_name: "Prague", country_name: "Czech Republic", country_code: "CZ" },

      # Southern Europe - Italy
      { code: "FCO", name: "Rome Fiumicino", city_name: "Rome", country_name: "Italy", country_code: "IT" },
      { code: "MXP", name: "Milan Malpensa", city_name: "Milan", country_name: "Italy", country_code: "IT" },
      { code: "VCE", name: "Venice Marco Polo", city_name: "Venice", country_name: "Italy", country_code: "IT" },
      { code: "NAP", name: "Naples", city_name: "Naples", country_name: "Italy", country_code: "IT" },
      { code: "CTA", name: "Catania", city_name: "Catania", country_name: "Italy", country_code: "IT" },
      { code: "OLB", name: "Olbia", city_name: "Olbia", country_name: "Italy", country_code: "IT" },
      { code: "PSA", name: "Pisa", city_name: "Pisa", country_name: "Italy", country_code: "IT" },

      # Southern Europe - Spain
      { code: "BCN", name: "Barcelona", city_name: "Barcelona", country_name: "Spain", country_code: "ES" },
      { code: "MAD", name: "Madrid", city_name: "Madrid", country_name: "Spain", country_code: "ES" },
      { code: "AGP", name: "Malaga", city_name: "Malaga", country_name: "Spain", country_code: "ES" },
      { code: "ALC", name: "Alicante", city_name: "Alicante", country_name: "Spain", country_code: "ES" },
      { code: "PMI", name: "Palma de Mallorca", city_name: "Palma de Mallorca", country_name: "Spain", country_code: "ES" },
      { code: "TFS", name: "Tenerife South", city_name: "Tenerife", country_name: "Spain", country_code: "ES" },
      { code: "LPA", name: "Gran Canaria", city_name: "Las Palmas", country_name: "Spain", country_code: "ES" },
      { code: "VLC", name: "Valencia", city_name: "Valencia", country_name: "Spain", country_code: "ES" },

      # Southern Europe - Other
      { code: "LIS", name: "Lisbon", city_name: "Lisbon", country_name: "Portugal", country_code: "PT" },
      { code: "ATH", name: "Athens", city_name: "Athens", country_name: "Greece", country_code: "GR" },

      # Eastern Europe
      { code: "BUD", name: "Budapest", city_name: "Budapest", country_name: "Hungary", country_code: "HU" },
      { code: "OTP", name: "Bucharest", city_name: "Bucharest", country_name: "Romania", country_code: "RO" },
      { code: "SOF", name: "Sofia", city_name: "Sofia", country_name: "Bulgaria", country_code: "BG" },

      # Middle East & Africa
      { code: "TLV", name: "Tel Aviv", city_name: "Tel Aviv", country_name: "Israel", country_code: "IL" },
      { code: "DXB", name: "Dubai", city_name: "Dubai", country_name: "United Arab Emirates", country_code: "AE" },
      { code: "HRG", name: "Hurghada", city_name: "Hurghada", country_name: "Egypt", country_code: "EG" },
      { code: "SSH", name: "Sharm el-Sheikh", city_name: "Sharm el-Sheikh", country_name: "Egypt", country_code: "EG" },
      { code: "RAK", name: "Marrakech", city_name: "Marrakech", country_name: "Morocco", country_code: "MA" },

      # Asia
      { code: "TBS", name: "Tbilisi", city_name: "Tbilisi", country_name: "Georgia", country_code: "GE" },
      { code: "BKK", name: "Bangkok", city_name: "Bangkok", country_name: "Thailand", country_code: "TH" },
    ]

    created = 0
    updated = 0

    destinations.each do |attrs|
      destination = AirbalticDestination.find_or_initialize_by(code: attrs[:code])

      if destination.new_record?
        created += 1
      else
        updated += 1
      end

      destination.assign_attributes(attrs.merge(last_synced_at: Time.current))
      destination.save!
    end

    puts "AirBaltic destinations seeded: #{created} created, #{updated} updated, #{destinations.count} total"
  end

  desc "List all AirBaltic destinations"
  task list_destinations: :environment do
    destinations = AirbalticDestination.ordered
    puts "AirBaltic destinations from RIX (#{destinations.count} total):"
    puts "-" * 60
    destinations.each do |dest|
      puts "#{dest.code.ljust(5)} #{dest.name.ljust(30)} #{dest.country_name}"
    end
  end

  desc "Test outbound dates API"
  task :test_dates_out, [ :destination_code ] => :environment do |t, args|
    code = args[:destination_code] || "LPA"
    puts "Testing outbound dates for RIX -> #{code}..."

    dates = Airbaltic::OutboundDatesService.new(code).call

    if dates.any?
      puts "Found #{dates.count} dates:"
      dates.first(10).each do |d|
        direct = d[:is_direct] ? "Direct" : "Connecting"
        price_str = d[:price] ? "€#{d[:price]}" : "Price N/A"
        puts "  #{d[:date]} - #{price_str} (#{direct})"
      end
      puts "  ..." if dates.count > 10
    else
      puts "No dates found"
    end
  end

  desc "Test inbound dates API"
  task :test_dates_in, [ :destination_code, :date_out ] => :environment do |t, args|
    code = args[:destination_code] || "LPA"
    date_out = args[:date_out] || Date.today.strftime("%Y-%m-%d")
    puts "Testing inbound dates for #{code} -> RIX (outbound: #{date_out})..."

    dates = Airbaltic::InboundDatesService.new(code, date_out).call

    if dates.any?
      puts "Found #{dates.count} dates:"
      dates.first(10).each do |d|
        direct = d[:is_direct] ? "Direct" : "Connecting"
        price_str = d[:price] ? "€#{d[:price]}" : "Price N/A"
        puts "  #{d[:date]} - #{price_str} (#{direct})"
      end
      puts "  ..." if dates.count > 10
    else
      puts "No dates found"
    end
  end

  desc "Test price fetch for a saved search"
  task :test_price_fetch, [ :flight_search_id ] => :environment do |t, args|
    search_id = args[:flight_search_id]

    unless search_id
      puts "Usage: rails airbaltic:test_price_fetch[flight_search_id]"
      exit 1
    end

    search = AirbalticFlightSearch.find(search_id)
    puts "Testing price fetch for flight search ##{search.id}:"
    puts "  Destination: #{search.airbaltic_destination.display_name}"
    puts "  Dates: #{search.date_out} - #{search.date_in}"

    result = Airbaltic::PriceFetchService.new(search).call

    if result[:success]
      puts "Success!"
      puts "  Out: €#{result[:price_out]}"
      puts "  In: €#{result[:price_in]}"
      puts "  Total: €#{result[:total]}"
    else
      puts "Error: #{result[:error]}"
    end
  end
end
