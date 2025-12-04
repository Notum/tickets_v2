require "net/http"
require "nokogiri"

module Bode
  class FlightsFetchService
    BASE_URL = "https://bode.lv".freeze

    def initialize(destination)
      @destination = destination
    end

    # Fetches all available flights for a destination
    # Returns array of flight hashes: { date_out:, date_in:, nights:, price:, airline:, order_url:, free_seats: }
    def call
      Rails.logger.info "[Bode::FlightsFetchService] Fetching flights for #{@destination.name}"

      html = fetch_page(@destination.full_url)
      return { success: false, error: "Failed to fetch page", flights: [] } unless html

      flights = parse_flights(html)
      Rails.logger.info "[Bode::FlightsFetchService] Found #{flights.count} flights"

      { success: true, flights: flights }
    rescue StandardError => e
      Rails.logger.error "[Bode::FlightsFetchService] Error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      { success: false, error: e.message, flights: [] }
    end

    private

    def fetch_page(url)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 15
      http.read_timeout = 30

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
      request["Accept"] = "text/html,application/xhtml+xml"
      request["Accept-Language"] = "ru,en;q=0.9"

      response = http.request(request)

      if response.code == "200"
        response.body
      else
        Rails.logger.error "[Bode::FlightsFetchService] HTTP #{response.code}"
        nil
      end
    end

    def parse_flights(html)
      doc = Nokogiri::HTML(html)
      flights = []

      # Find all table rows with flight data
      doc.css("table tr").each do |row|
        flight = parse_flight_row(row)
        next unless flight

        # Group by date range and keep only the lowest price
        existing = flights.find { |f| f[:date_out] == flight[:date_out] && f[:date_in] == flight[:date_in] }

        if existing
          if flight[:price] < existing[:price]
            existing.merge!(flight)
          end
        else
          flights << flight
        end
      end

      flights.sort_by { |f| f[:date_out] }
    end

    def parse_flight_row(row)
      cells = row.css("td")
      return nil if cells.size < 5

      # Actual structure from bode.lv:
      # 0: Route + Order link (e.g., "Рига - Анталья - Рига" with nested <a> for order)
      # 1: Price (e.g., "335 €")
      # 2: Airline (e.g., "airBaltic")
      # 3: Dates + free seats (e.g., "01.04.2026 - 04.04.2026\n5 free seat(s)")
      # 4: Nights (e.g., "3")
      # 5: Order button (another link)

      # Extract order link from cell 0 or 5
      order_link = nil
      link = cells[0]&.css('a[href*="charterid"]')&.first || cells[5]&.css('a[href*="charterid"]')&.first
      if link
        href = link["href"]
        order_link = href.start_with?("http") ? href : "#{BASE_URL}/#{href.sub(/^\//, '')}"
      end

      # Extract price from cell 1
      price_text = cells[1]&.text&.strip
      return nil unless price_text&.match?(/\d+\s*€/)
      price = price_text.gsub(/[^\d]/, "").to_i

      # Extract airline from cell 2
      airline = cells[2]&.text&.strip
      airline = nil if airline.blank?

      # Extract dates and free seats from cell 3
      dates_cell_text = cells[3]&.text&.strip || ""

      # Parse dates (handle various dash types)
      date_match = dates_cell_text.match(/(\d{2})\.(\d{2})\.(\d{4})\s*[-–—]\s*(\d{2})\.(\d{2})\.(\d{4})/)
      return nil unless date_match

      begin
        date_out = Date.new(date_match[3].to_i, date_match[2].to_i, date_match[1].to_i)
        date_in = Date.new(date_match[6].to_i, date_match[5].to_i, date_match[4].to_i)
      rescue ArgumentError
        return nil
      end

      # Extract free seats from the same cell
      # The text might be concatenated like "01.04.2026 - 04.04.20265 free seat(s)"
      # where 2026 and 5 are joined. We match the 1-2 digits after a 4-digit year.
      free_seats = nil
      seats_match = dates_cell_text.match(/\d{4}(\d{1,2})\s*free\s*seat/i)
      free_seats = seats_match[1].to_i if seats_match

      # Extract nights from cell 4
      nights_text = cells[4]&.text&.strip
      nights = nights_text&.match?(/^\d+$/) ? nights_text.to_i : (date_in - date_out).to_i

      {
        date_out: date_out,
        date_in: date_in,
        nights: nights,
        price: price,
        airline: airline,
        order_url: order_link,
        free_seats: free_seats
      }
    end
  end
end
