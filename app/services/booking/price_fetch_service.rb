module Booking
  class PriceFetchService
    def initialize(booking_search)
      @booking_search = booking_search
    end

    def call
      Rails.logger.info "[Booking::PriceFetchService] Fetching price for search ##{@booking_search.id} (#{@booking_search.hotel_name})"

      unless FlaresolverrService.available?
        return update_with_error("Byparr service is not available")
      end

      hotel_url = build_hotel_url
      Rails.logger.info "[Booking::PriceFetchService] Fetching: #{hotel_url}"

      service = FlaresolverrService.new
      html = fetch_with_retry(service, hotel_url)

      if html.is_a?(String) && html.length > 10_000
        parse_and_save_prices(html)
      elsif html.is_a?(String) && html.include?("challenge")
        update_with_error("Cloudflare challenge not solved - please try again")
      else
        update_with_error("Unexpected response format or incomplete page")
      end
    rescue FlaresolverrService::FlaresolverrError => e
      Rails.logger.error "[Booking::PriceFetchService] Error: #{e.message}"
      update_with_error(e.message)
    rescue StandardError => e
      Rails.logger.error "[Booking::PriceFetchService] Error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      update_with_error(e.message)
    end

    private

    def fetch_with_retry(service, url, max_retries: 2)
      retries = 0
      html = nil

      while retries <= max_retries
        Rails.logger.info "[Booking::PriceFetchService] Attempt #{retries + 1}"
        html = service.fetch(url)

        # Check if we got actual content (not a challenge page)
        # A real Cloudflare challenge page is small (<50KB) and has specific markers
        if html.is_a?(String) && html.length > 10_000 && !cloudflare_challenge?(html)
          Rails.logger.info "[Booking::PriceFetchService] Got valid response (#{html.length} bytes)"
          return html
        else
          Rails.logger.warn "[Booking::PriceFetchService] Got challenge page or incomplete response (#{html.to_s.length} bytes)"
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
      # Use stored URL if available, otherwise construct from hotel_id
      if @booking_search.hotel_url.present?
        base_url = @booking_search.hotel_url.split("?").first
      else
        # Fallback - this might not always work without the proper country code
        base_url = "https://www.booking.com/hotel/#{@booking_search.hotel_id}.html"
      end

      params = {
        checkin: @booking_search.check_in.to_s,
        checkout: @booking_search.check_out.to_s,
        group_adults: @booking_search.adults,
        no_rooms: @booking_search.rooms,
        selected_currency: @booking_search.currency
      }

      "#{base_url}?#{URI.encode_www_form(params)}"
    end

    def parse_and_save_prices(html)
      # Extract room prices from embedded data
      # Format can be JSON: {"b_room_id":"123",...} or JS object: {b_room_id: '123',...}
      prices = html.scan(/b_price['"]*:\s*['"]([^'"]+)['"]/).flatten
      raw_prices = html.scan(/b_raw_price['"]*:\s*['"]?(\d+(?:\.\d+)?)['"]?/).flatten.map(&:to_f)
      room_names = html.scan(/b_name['"]*:\s*['"]([^'"]{5,100})['"]/).flatten
      room_ids = html.scan(/b_room_id['"]*:\s*['"](\d+)['"]/).flatten
      block_ids = html.scan(/b_block_id['"]*:\s*['"]([^'"]+)['"]/).flatten

      # Get per night prices
      per_night_prices = html.scan(/b_avg_price_per_night[^'"]*['"]*:\s*['"]?(\d+(?:\.\d+)?)['"]?/).flatten.map(&:to_f)

      if raw_prices.any?
        # Check if we're tracking a specific room
        if @booking_search.room_id.present?
          # Find the specific room by room_id
          room_index = room_ids.index(@booking_search.room_id)

          if room_index.nil?
            # Room not found - it's sold out
            Rails.logger.info "[Booking::PriceFetchService] Room #{@booking_search.room_id} not found - marking as room_sold_out"
            return update_room_sold_out
          end

          new_price = raw_prices[room_index]
          new_price_per_night = per_night_prices[room_index] if per_night_prices.any? && per_night_prices.length > room_index
          new_room_name = room_names[room_index] if room_names.any? && room_names.length > room_index
        else
          # Legacy behavior: find the cheapest available room
          min_price_index = raw_prices.index(raw_prices.min)
          new_price = raw_prices[min_price_index]
          new_price_per_night = per_night_prices[min_price_index] if per_night_prices.any?
          new_room_name = room_names[min_price_index] if room_names.any?
        end

        previous_price = @booking_search.price

        @booking_search.update!(
          price: new_price,
          price_per_night: new_price_per_night,
          room_name: new_room_name,
          status: "priced",
          priced_at: Time.current,
          api_response: { prices: raw_prices, room_names: room_names, room_ids: room_ids }.to_json
        )

        # Record price history if changed
        @booking_search.record_price_if_changed(new_price, new_price_per_night, new_room_name)

        Rails.logger.info "[Booking::PriceFetchService] Price saved: #{new_price} #{@booking_search.currency}"

        result = {
          success: true,
          price: new_price,
          price_per_night: new_price_per_night,
          room_name: new_room_name
        }

        # Check for price drop
        if previous_price.present? && new_price < previous_price
          price_drop = previous_price - new_price
          result[:price_drop] = {
            booking_search_id: @booking_search.id,
            hotel_name: @booking_search.hotel_name,
            city_name: @booking_search.city_name,
            room_name: @booking_search.room_name,
            check_in: @booking_search.check_in,
            check_out: @booking_search.check_out,
            previous_price: previous_price,
            current_price: new_price,
            savings: price_drop,
            currency: @booking_search.currency
          }
          Rails.logger.info "[Booking::PriceFetchService] Price dropped by #{price_drop} #{@booking_search.currency}!"
        end

        result
      else
        # Try alternative price extraction
        alt_prices = extract_alternative_prices(html)
        if alt_prices[:price]
          previous_price = @booking_search.price

          @booking_search.update!(
            price: alt_prices[:price],
            price_per_night: alt_prices[:price_per_night],
            room_name: alt_prices[:room_name],
            status: "priced",
            priced_at: Time.current
          )

          @booking_search.record_price_if_changed(alt_prices[:price], alt_prices[:price_per_night], alt_prices[:room_name])

          result = { success: true }.merge(alt_prices)

          if previous_price.present? && alt_prices[:price] < previous_price
            price_drop = previous_price - alt_prices[:price]
            result[:price_drop] = {
              booking_search_id: @booking_search.id,
              hotel_name: @booking_search.hotel_name,
              city_name: @booking_search.city_name,
              room_name: @booking_search.room_name,
              check_in: @booking_search.check_in,
              check_out: @booking_search.check_out,
              previous_price: previous_price,
              current_price: alt_prices[:price],
              savings: price_drop,
              currency: @booking_search.currency
            }
          end

          result
        else
          # Check if hotel is genuinely sold out (only when no prices found)
          if hotel_sold_out?(html)
            update_sold_out
          else
            update_with_error("Could not extract prices from page")
          end
        end
      end
    end

    def hotel_sold_out?(html)
      # Look for specific sold out indicators in the page content
      # These patterns indicate the hotel has no availability for the selected dates
      sold_out_indicators = [
        /"soldOut"\s*:\s*true/i,
        /"isPropertyFullySoldOut"\s*:\s*true/i,
        /class="[^"]*sold-out[^"]*"/i,
        /"availability"\s*:\s*"not_available"/i,
        />We have no availability<\/span>/i,
        />Sold out<\/span>/i
      ]

      sold_out_indicators.any? { |pattern| html.match?(pattern) }
    end

    def extract_alternative_prices(html)
      # Try different price patterns
      result = { price: nil, price_per_night: nil, room_name: nil }

      # Pattern: €297 or EUR 297
      if @booking_search.currency == "EUR"
        euro_prices = html.scan(/€\s*(\d+(?:,\d+)?(?:\.\d+)?)/).flatten
        euro_prices = euro_prices.map { |p| p.gsub(",", "").to_f }.select { |p| p > 0 }
        result[:price] = euro_prices.min if euro_prices.any?
      else
        usd_prices = html.scan(/\$\s*(\d+(?:,\d+)?(?:\.\d+)?)/).flatten
        usd_prices = usd_prices.map { |p| p.gsub(",", "").to_f }.select { |p| p > 0 }
        result[:price] = usd_prices.min if usd_prices.any?
      end

      result
    end

    def update_sold_out
      @booking_search.update!(status: "sold_out", priced_at: Time.current)
      Rails.logger.info "[Booking::PriceFetchService] Hotel is sold out"
      { success: true, sold_out: true }
    end

    def update_room_sold_out
      @booking_search.update!(status: "room_sold_out", priced_at: Time.current)
      Rails.logger.info "[Booking::PriceFetchService] Room is sold out"
      { success: true, room_sold_out: true }
    end

    def update_with_error(message)
      @booking_search.update!(status: "error", api_response: { error: message }.to_json)
      { success: false, error: message }
    end
  end
end
