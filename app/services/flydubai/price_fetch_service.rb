require "json"

module Flydubai
  class PriceFetchService
    SEARCH_BASE_URL = "https://flights2.flydubai.com/en/results/rt/a1c0i0".freeze
    ORIGIN = "RIX".freeze
    DESTINATION = "DXB".freeze

    def initialize(flight_search)
      @flight_search = flight_search
    end

    def call
      Rails.logger.info "[Flydubai::PriceFetchService] Fetching prices for flight search ##{@flight_search.id}"

      flaresolverr = FlaresolverrService.new
      search_page_url = build_search_page_url

      Rails.logger.info "[Flydubai::PriceFetchService] Fetching rendered page: #{search_page_url}"

      begin
        # Fetch the rendered search results page - Angular app will have loaded prices
        html_response = flaresolverr.fetch(search_page_url)
      rescue FlaresolverrService::FlaresolverrError => e
        return update_with_error("FlareSolverr error: #{e.message}")
      end

      # Try to extract prices from rendered HTML
      price_data = extract_prices_from_html(html_response)

      if price_data
        save_prices(price_data)
      else
        update_with_error("Could not extract prices from page")
      end
    rescue StandardError => e
      Rails.logger.error "[Flydubai::PriceFetchService] Error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      update_with_error(e.message)
    end

    private

    def build_search_page_url
      date_out_str = @flight_search.date_out.strftime("%Y%m%d")
      date_in_str = @flight_search.date_in.strftime("%Y%m%d")

      "#{SEARCH_BASE_URL}/#{ORIGIN}_#{DESTINATION}/#{date_out_str}_#{date_in_str}?cabinClass=Economy&isOriginMetro=false&isDestMetro=false&pm=cash"
    end

    def extract_prices_from_html(html)
      return nil unless html.is_a?(String) && html.length > 1000

      Rails.logger.info "[Flydubai::PriceFetchService] Parsing HTML response (#{html.length} bytes)"

      # Save HTML for debugging
      debug_file = Rails.root.join("tmp", "flydubai_debug_#{@flight_search.id}.html")
      File.write(debug_file, html)
      Rails.logger.info "[Flydubai::PriceFetchService] Saved debug HTML to #{debug_file}"

      # FlyDubai Angular app structure:
      # Selected calendar tabs have class "calendar-backgrnd-selected"
      # Prices are in <label id="lblAmount">199.98</label> inside calAmount-selected
      # There are two selected tabs: outbound (first) and inbound (second)

      # Find all prices from selected calendar tabs
      # Pattern: calendar-backgrnd-selected ... lblAmount ... >PRICE<
      selected_prices = []

      # Match selected calendar sections and extract their prices
      html.scan(/calendar-backgrnd-selected.*?id="lblAmount"[^>]*>(\d+\.?\d*)<\/label>/mi) do |match|
        price = match[0].to_f
        selected_prices << price if price > 50  # Sanity check
      end

      Rails.logger.info "[Flydubai::PriceFetchService] Found #{selected_prices.length} selected prices: #{selected_prices.inspect}"

      if selected_prices.length >= 2
        outbound_price = selected_prices[0]
        inbound_price = selected_prices[1]

        Rails.logger.info "[Flydubai::PriceFetchService] Outbound: #{outbound_price} EUR, Inbound: #{inbound_price} EUR"

        return {
          price_out: outbound_price,
          price_in: inbound_price,
          total: (outbound_price + inbound_price).round(2),
          is_direct: html.include?("Direct") || html.include?("direct")
        }
      end

      # Fallback: Try to find any lblAmount prices on the page
      all_prices = html.scan(/id="lblAmount"[^>]*>(\d+\.?\d*)<\/label>/i).flatten.map(&:to_f)
      all_prices = all_prices.select { |p| p > 50 && p < 2000 }  # Filter reasonable flight prices

      Rails.logger.info "[Flydubai::PriceFetchService] All lblAmount prices found: #{all_prices.inspect}"

      if all_prices.length >= 2
        # Take first two reasonable prices as outbound and inbound
        outbound_price = all_prices[0]
        inbound_price = all_prices[1]

        Rails.logger.info "[Flydubai::PriceFetchService] Using first two prices - Outbound: #{outbound_price} EUR, Inbound: #{inbound_price} EUR"

        return {
          price_out: outbound_price,
          price_in: inbound_price,
          total: (outbound_price + inbound_price).round(2),
          is_direct: html.include?("Direct") || html.include?("direct")
        }
      end

      Rails.logger.warn "[Flydubai::PriceFetchService] Could not extract prices from HTML"
      nil
    end

    def extract_prices_from_json(data)
      # Handle different JSON structures
      if data.is_a?(Array) && data.first&.dig("totalFare")
        # lowestTotalFare array format
        lowest = data.find { |f| f["cabin"]&.downcase == "economy" }
        if lowest && lowest["totalFare"].to_f > 0
          total = lowest["totalFare"].to_f
          return {
            price_out: (total / 2).round(2),
            price_in: (total / 2).round(2),
            total: total,
            is_direct: true
          }
        end
      elsif data.is_a?(Hash) && data["lowestTotalFare"]
        # Full API response format
        lowest = data["lowestTotalFare"].find { |f| f["cabin"]&.downcase == "economy" }
        if lowest && lowest["totalFare"].to_f > 0
          total = lowest["totalFare"].to_f
          return {
            price_out: (total / 2).round(2),
            price_in: (total / 2).round(2),
            total: total,
            is_direct: true
          }
        end
      end
      nil
    end

    def save_prices(price_data)
      new_total_price = price_data[:total]
      previous_total_price = @flight_search.total_price

      @flight_search.update!(
        price_out: price_data[:price_out],
        price_in: price_data[:price_in],
        is_direct_out: price_data[:is_direct],
        is_direct_in: price_data[:is_direct],
        status: "priced",
        priced_at: Time.current,
        api_response: price_data.to_json
      )

      # Record price history if price changed
      @flight_search.record_price_if_changed(price_data[:price_out], price_data[:price_in], new_total_price)

      Rails.logger.info "[Flydubai::PriceFetchService] Prices saved: OUT=#{price_data[:price_out]}, IN=#{price_data[:price_in]}, TOTAL=#{new_total_price}"

      result = { success: true, price_out: price_data[:price_out], price_in: price_data[:price_in], total: new_total_price }

      # Check for price drop
      if previous_total_price.present? && new_total_price < previous_total_price
        price_drop = previous_total_price - new_total_price
        result[:price_drop] = {
          flight_search_id: @flight_search.id,
          destination_name: "Dubai",
          destination_code: DESTINATION,
          date_out: @flight_search.date_out,
          date_in: @flight_search.date_in,
          previous_price: previous_total_price,
          current_price: new_total_price,
          savings: price_drop
        }
        Rails.logger.info "[Flydubai::PriceFetchService] Price dropped by #{price_drop} EUR!"
      end

      result
    end

    def update_with_error(message)
      @flight_search.update!(status: "error", api_response: { error: message }.to_json)
      { success: false, error: message }
    end
  end
end
