namespace :booking do
  desc "Test if Byparr can fetch from Booking.com"
  task test_fetch: :environment do
    puts "=" * 60
    puts "Testing Byparr access to Booking.com"
    puts "=" * 60

    # First check if FlareSolverr/Byparr is available
    unless FlaresolverrService.available?
      puts "ERROR: FlareSolverr/Byparr is not running!"
      puts "Start it with: docker run -d --name flaresolverr -p 8191:8191 ghcr.io/thephaseless/byparr:latest"
      exit 1
    end

    puts "✓ Byparr is available"
    puts

    service = FlaresolverrService.new

    # Test 1: Simple GET to booking.com homepage
    puts "Test 1: GET booking.com homepage"
    puts "-" * 40
    begin
      result = service.fetch("https://www.booking.com")
      if result.is_a?(String)
        puts "✓ Got HTML response (#{result.length} bytes)"
        puts "  Contains 'booking': #{result.include?('booking') || result.include?('Booking')}"
      else
        puts "✓ Got JSON response: #{result.keys.first(5).join(', ')}..."
      end
    rescue FlaresolverrService::FlaresolverrError => e
      puts "✗ FAILED: #{e.message}"
    end
    puts

    # Test 2: GET a hotel search page
    puts "Test 2: GET hotel search results page"
    puts "-" * 40
    search_url = "https://www.booking.com/searchresults.html?ss=Calpe&checkin=2026-08-15&checkout=2026-08-17&group_adults=2&no_rooms=1"
    begin
      result = service.fetch(search_url)
      if result.is_a?(String)
        puts "✓ Got HTML response (#{result.length} bytes)"
        # Check for signs of successful page load vs blocked
        if result.include?("property-card") || result.include?("sr_property_block")
          puts "  ✓ Contains hotel property cards"
        elsif result.include?("captcha") || result.include?("challenge")
          puts "  ⚠ Page contains captcha/challenge"
        else
          puts "  ? Could not detect property cards"
        end
      else
        puts "✓ Got JSON response"
      end
    rescue FlaresolverrService::FlaresolverrError => e
      puts "✗ FAILED: #{e.message}"
    end
    puts

    # Test 3: Try the acid_carousel endpoint with session
    puts "Test 3: POST acid_carousel endpoint (with session)"
    puts "-" * 40
    begin
      # First establish a session by visiting the hotel page
      get_url = "https://www.booking.com/hotel/es/europa-calpe.html?checkin=2026-08-15&checkout=2026-08-29"
      post_url = "https://www.booking.com/acid_carousel"

      post_data = {
        dest_type: "",
        ufi: "-375124",
        checkin: "2026-08-15",
        checkout: "2026-08-29",
        currency: "EUR",
        filter_aggregates: "",
        sb_travel_purpose: "leisure",
        type: "48",
        carousel_type: "48",
        nr_rooms_needed: "1",
        adults_total: "2",
        children_total: "0",
        children_ages_total: "",
        optional: "240790"
      }

      # Convert to URL-encoded form data
      form_data = URI.encode_www_form(post_data)

      headers = {
        "Content-Type" => "application/x-www-form-urlencoded; charset=UTF-8",
        "X-Requested-With" => "XMLHttpRequest",
        "Accept" => "*/*"
      }

      result = service.fetch_with_session(get_url, post_url, form_data, headers: headers)

      if result.is_a?(String)
        puts "✓ Got response (#{result.length} bytes)"
        if result.include?("hotel") || result.include?("property")
          puts "  ✓ Response contains hotel/property data"
        end
        puts "  First 500 chars: #{result[0..500]}..."
      else
        puts "✓ Got JSON response!"
        puts "  Keys: #{result.keys.first(10).join(', ')}"
      end
    rescue FlaresolverrService::FlaresolverrError => e
      puts "✗ FAILED: #{e.message}"
    end
    puts

    puts "=" * 60
    puts "Testing complete"
    puts "=" * 60
  end

  desc "Test simple hotel price extraction from Booking.com"
  task test_hotel_page: :environment do
    puts "Testing hotel page price extraction..."
    puts

    unless FlaresolverrService.available?
      puts "ERROR: Byparr is not running!"
      exit 1
    end

    service = FlaresolverrService.new

    # URL with specific dates - this should show prices
    url = "https://www.booking.com/hotel/es/europa-calpe.html?checkin=2026-08-15&checkout=2026-08-17&group_adults=2&no_rooms=1&selected_currency=EUR"

    puts "Fetching: #{url}"
    puts

    begin
      result = service.fetch(url)

      if result.is_a?(String)
        puts "Got HTML (#{result.length} bytes)"

        # Try to find price information
        # Booking.com uses various patterns for prices
        price_patterns = [
          /data-price="(\d+)"/,
          /€\s*(\d+)/,
          /EUR\s*(\d+)/,
          /"price":\s*(\d+)/,
          /price_breakdown.*?(\d+)/m
        ]

        puts
        puts "Looking for prices..."
        price_patterns.each do |pattern|
          matches = result.scan(pattern).flatten.uniq.first(5)
          if matches.any?
            puts "  Found with #{pattern.inspect}: #{matches.join(', ')}"
          end
        end

        # Check if we got blocked
        if result.include?("captcha") || result.include?("robot")
          puts
          puts "⚠ Warning: Page may contain captcha/robot check"
        end

        # Save HTML for inspection
        File.write("tmp/booking_test.html", result)
        puts
        puts "Saved full HTML to tmp/booking_test.html for inspection"
      else
        puts "Got JSON response:"
        puts JSON.pretty_generate(result).first(1000)
      end
    rescue FlaresolverrService::FlaresolverrError => e
      puts "FAILED: #{e.message}"
    end
  end
end
