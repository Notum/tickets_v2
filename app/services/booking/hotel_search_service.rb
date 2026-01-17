module Booking
  class HotelSearchService
    def initialize(city:, hotel_name:, check_in:, check_out:, adults: 2, rooms: 1, currency: "EUR")
      @city = city
      @hotel_name = hotel_name
      @check_in = check_in
      @check_out = check_out
      @adults = adults
      @rooms = rooms
      @currency = currency
    end

    def call
      Rails.logger.info "[Booking::HotelSearchService] Searching for '#{@hotel_name}' in #{@city}"

      unless FlaresolverrService.available?
        return { success: false, error: "Byparr service is not available" }
      end

      search_url = build_search_url
      Rails.logger.info "[Booking::HotelSearchService] Fetching: #{search_url}"

      service = FlaresolverrService.new
      html = fetch_with_retry(service, search_url)

      if html.is_a?(String) && html.length > 10_000
        hotels = parse_hotels(html)
        Rails.logger.info "[Booking::HotelSearchService] Found #{hotels.count} hotels"
        { success: true, hotels: hotels }
      elsif html.is_a?(String) && html.include?("challenge")
        { success: false, error: "Cloudflare challenge not solved - please try again" }
      else
        { success: false, error: "Unexpected response format or incomplete page" }
      end
    rescue FlaresolverrService::FlaresolverrError => e
      Rails.logger.error "[Booking::HotelSearchService] Error: #{e.message}"
      { success: false, error: e.message }
    rescue StandardError => e
      Rails.logger.error "[Booking::HotelSearchService] Error: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      { success: false, error: e.message }
    end

    private

    def fetch_with_retry(service, url, max_retries: 2)
      retries = 0
      html = nil

      while retries <= max_retries
        Rails.logger.info "[Booking::HotelSearchService] Attempt #{retries + 1}"
        html = service.fetch(url)

        # Check if we got actual content (not a challenge page)
        # A real Cloudflare challenge page is small (<50KB) and has specific markers
        if html.is_a?(String) && html.length > 10_000 && !cloudflare_challenge?(html)
          Rails.logger.info "[Booking::HotelSearchService] Got valid response (#{html.length} bytes)"
          return html
        else
          Rails.logger.warn "[Booking::HotelSearchService] Got challenge page or incomplete response (#{html.to_s.length} bytes)"
          retries += 1
          sleep 3 if retries <= max_retries # Wait before retry
        end
      end

      # Return last attempt's result
      html
    end

    def cloudflare_challenge?(html)
      # Only consider it a challenge if page is small AND has Cloudflare markers
      return false if html.length > 50_000

      html.include?("cf-browser-verification") ||
        html.include?("Just a moment...") ||
        html.include?("Checking your browser") ||
        (html.include?("challenge-platform") && html.length < 20_000)
    end

    def build_search_url
      params = {
        ss: "#{@hotel_name}, #{@city}",
        checkin: @check_in.to_s,
        checkout: @check_out.to_s,
        group_adults: @adults,
        no_rooms: @rooms,
        selected_currency: @currency
      }

      "https://www.booking.com/searchresults.html?#{URI.encode_www_form(params)}"
    end

    def parse_hotels(html)
      hotels = []

      # Extract hotels from property cards in search results
      # Pattern: href="https://www.booking.com/hotel/XX/hotel-slug.html?..." followed by img alt="Hotel Name"
      # The property cards have this structure:
      # <a href="https://www.booking.com/hotel/es/europa-calpe.html?...">
      #   <img alt="Port Europa" ...>

      # Find all hotel URLs with their names from property cards
      # Look for the pattern: href to hotel page followed by img with alt text
      property_cards = extract_property_cards(html)

      property_cards.each do |card|
        hotel = parse_property_card(card)
        hotels << hotel if hotel && hotel[:name].present?
      end

      # If no property cards found, try alternative extraction
      if hotels.empty?
        hotels = extract_from_json_data(html)
      end

      # Filter by hotel name similarity if we have results and a search term
      if hotels.any? && @hotel_name.present?
        filtered = hotels.select { |h| name_matches?(h[:name], @hotel_name) }
        # If filter removes everything, return all results
        hotels = filtered.any? ? filtered : hotels
      end

      # Remove duplicates by hotel_id
      hotels.uniq { |h| h[:hotel_id] }.first(10)
    end

    def extract_property_cards(html)
      # Split HTML by property-card markers and get chunks
      cards = []

      # Find each property card section
      # Property cards are marked with data-testid="property-card"
      html.scan(/data-testid="property-card"(.*?)(?=data-testid="property-card"|<\/main>|\z)/m) do |match|
        cards << match[0]
      end

      Rails.logger.info "[Booking::HotelSearchService] Found #{cards.count} property card chunks"
      cards
    end

    def parse_property_card(card_html)
      # Extract hotel URL - format: href="https://www.booking.com/hotel/XX/hotel-slug.html?..."
      url_match = card_html.match(/href="(https:\/\/www\.booking\.com\/hotel\/[a-z]{2}\/[^"]+\.html[^"]*)"/)
      return nil unless url_match

      full_url = url_match[1]

      # Extract hotel slug from URL (e.g., "europa-calpe" from ".../hotel/es/europa-calpe.html?...")
      slug_match = full_url.match(/\/hotel\/[a-z]{2}\/([^.?]+)/)
      hotel_slug = slug_match ? slug_match[1] : nil

      # Extract hotel name from img alt attribute
      # Pattern: <img ... alt="Hotel Name" ...>
      name_match = card_html.match(/alt="([^"]+)"/)
      hotel_name = name_match ? name_match[1] : nil

      # Skip if name looks like a generic placeholder
      return nil if hotel_name.nil? || hotel_name.length < 3

      # Clean the URL - remove tracking parameters for storage, keep essential ones
      clean_url = full_url.split("?").first

      {
        hotel_id: hotel_slug || SecureRandom.hex(4),
        name: hotel_name,
        price: nil,
        raw_price: nil,
        url: clean_url
      }
    end

    def extract_from_json_data(html)
      hotels = []

      # Try to find hotel data in JSON embedded in the page
      # Look for patterns like "hotelId": 123456 near hotel names

      # Pattern 1: basicPropertyData with id and name
      html.scan(/"basicPropertyData":\s*\{[^}]*"id"\s*:\s*(\d+)[^}]*\}.*?"name"\s*:\s*"([^"]+)"/m) do |id, name|
        hotels << {
          hotel_id: id,
          name: name,
          price: nil,
          raw_price: nil,
          url: nil
        }
      end

      # Pattern 2: Look for hotelId with nearby displayName
      if hotels.empty?
        html.scan(/"hotelId"\s*:\s*(\d+)/) do |match|
          hotel_id = match[0]
          # Try to find name near this ID
          idx = html.index("\"hotelId\":#{hotel_id}")
          next unless idx

          context = html[[idx - 500, 0].max..idx + 1000]
          name_match = context.match(/"displayName":\s*\{\s*"text"\s*:\s*"([^"]+)"/)
          name_match ||= context.match(/"name"\s*:\s*"([^"]+)"/)

          if name_match
            hotels << {
              hotel_id: hotel_id,
              name: name_match[1],
              price: nil,
              raw_price: nil,
              url: nil
            }
          end
        end
      end

      hotels
    end

    def name_matches?(hotel_name, search_name)
      return true if search_name.blank?

      hotel_lower = hotel_name.to_s.downcase
      search_lower = search_name.to_s.downcase

      # Direct inclusion check
      return true if hotel_lower.include?(search_lower)
      return true if search_lower.include?(hotel_lower)

      # Check if hotel name contains search terms
      search_words = search_lower.split(/\s+/)
      matching_words = search_words.count { |word| hotel_lower.include?(word) }

      # Match if at least half of the search words are found
      matching_words >= (search_words.length / 2.0).ceil
    end
  end
end
