module Booking
  class RoomFetchService
    def initialize(hotel_url:, check_in:, check_out:, adults: 2, rooms: 1, currency: "EUR")
      @hotel_url = hotel_url
      @check_in = check_in
      @check_out = check_out
      @adults = adults
      @rooms = rooms
      @currency = currency
    end

    def call
      Rails.logger.info "[Booking::RoomFetchService] Fetching rooms for #{@hotel_url}"

      unless FlaresolverrService.available?
        return { success: false, error: "Byparr service is not available" }
      end

      url = build_hotel_url
      Rails.logger.info "[Booking::RoomFetchService] Fetching: #{url}"

      service = FlaresolverrService.new
      html = fetch_with_retry(service, url)

      if html.is_a?(String) && html.length > 10_000
        rooms = parse_rooms(html)
        Rails.logger.info "[Booking::RoomFetchService] Found #{rooms.count} rooms"
        { success: true, rooms: rooms }
      elsif html.is_a?(String) && html.include?("challenge")
        { success: false, error: "Cloudflare challenge not solved - please try again" }
      else
        { success: false, error: "Unexpected response format or incomplete page" }
      end
    rescue FlaresolverrService::FlaresolverrError => e
      Rails.logger.error "[Booking::RoomFetchService] Error: #{e.message}"
      { success: false, error: e.message }
    rescue StandardError => e
      Rails.logger.error "[Booking::RoomFetchService] Error: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      { success: false, error: e.message }
    end

    private

    def fetch_with_retry(service, url, max_retries: 2)
      retries = 0
      html = nil

      while retries <= max_retries
        Rails.logger.info "[Booking::RoomFetchService] Attempt #{retries + 1}"
        html = service.fetch(url)

        # Check if we got actual content (not a challenge page)
        # A real Cloudflare challenge page is small (<50KB) and has specific markers
        if html.is_a?(String) && html.length > 10_000 && !cloudflare_challenge?(html)
          Rails.logger.info "[Booking::RoomFetchService] Got valid response (#{html.length} bytes)"
          return html
        else
          Rails.logger.warn "[Booking::RoomFetchService] Got challenge page or incomplete response (#{html.to_s.length} bytes)"
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

    def build_hotel_url
      # Use stored URL, strip any existing params and add our own
      base_url = @hotel_url.split("?").first

      params = {
        checkin: @check_in.to_s,
        checkout: @check_out.to_s,
        group_adults: @adults,
        no_rooms: @rooms,
        selected_currency: @currency
      }

      "#{base_url}?#{URI.encode_www_form(params)}"
    end

    def parse_rooms(html)
      rooms = []

      # Extract room data from embedded data
      # Format can be JSON: {"b_room_id":"123",...} or JS object: {b_room_id: '123',...}

      # Collect all data points - try both JSON and JS formats
      # JSON format: "b_room_id":"value" or JS format: b_room_id: 'value'
      room_ids = html.scan(/b_room_id['"]*:\s*['"](\d+)['"]/).flatten.uniq
      block_ids = html.scan(/b_block_id['"]*:\s*['"]([^'"]+)['"]/).flatten
      room_names = html.scan(/b_name['"]*:\s*['"]([^'"]{5,100})['"]/).flatten
      raw_prices = html.scan(/b_raw_price['"]*:\s*['"]?(\d+(?:\.\d+)?)['"]?/).flatten.map(&:to_f)
      per_night_prices = html.scan(/b_avg_price_per_night[^'"]*['"]*:\s*['"]?(\d+(?:\.\d+)?)['"]?/).flatten.map(&:to_f)

      Rails.logger.info "[Booking::RoomFetchService] Found #{room_ids.count} room_ids, #{block_ids.count} block_ids, #{room_names.count} names, #{raw_prices.count} prices"

      # Try to match room data by index - this works when the data appears in order
      if room_ids.any? && raw_prices.any?
        room_count = [ room_ids.count, raw_prices.count ].min

        room_count.times do |i|
          room = {
            room_id: room_ids[i],
            block_id: block_ids[i],
            name: room_names[i] || "Room #{i + 1}",
            price: raw_prices[i],
            price_per_night: per_night_prices[i]
          }

          # Only add valid rooms with prices
          next if room[:price].nil? || room[:price] <= 0

          rooms << room
        end
      end

      # If simple extraction failed, try alternative extraction using context
      if rooms.empty?
        rooms = extract_rooms_from_context(html)
      end

      # Deduplicate by room_id and block_id combination
      rooms.uniq { |r| [ r[:room_id], r[:block_id] ] }
    end

    def extract_rooms_from_context(html)
      rooms = []

      # Find each room block by looking for b_room_id and extracting nearby data
      # Handle both JSON format ("b_room_id":"123") and JS format (b_room_id: '123')
      html.scan(/b_room_id['"]*:\s*['"](\d+)['"]/) do |match|
        room_id = match[0]
        idx = html.index(/b_room_id['"]*:\s*['"]#{room_id}['"]/)
        next unless idx

        # Get context around this room_id
        context = html[[ idx - 200, 0 ].max..idx + 800]

        # Handle both JSON and JS object formats
        block_id_match = context.match(/b_block_id['"]*:\s*['"]([^'"]+)['"]/)
        name_match = context.match(/b_name['"]*:\s*['"]([^'"]+)['"]/)
        price_match = context.match(/b_raw_price['"]*:\s*['"]?(\d+(?:\.\d+)?)['"]?/)
        per_night_match = context.match(/b_avg_price_per_night[^'"]*['"]*:\s*['"]?(\d+(?:\.\d+)?)['"]?/)

        next unless price_match

        rooms << {
          room_id: room_id,
          block_id: block_id_match ? block_id_match[1] : nil,
          name: name_match ? name_match[1] : "Room",
          price: price_match[1].to_f,
          price_per_night: per_night_match ? per_night_match[1].to_f : nil
        }
      end

      rooms
    end
  end
end
