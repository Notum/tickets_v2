require "net/http"
require "json"

module Norwegian
  class PriceFetchService
    FARE_CALENDAR_API = "https://www.norwegian.com/api/fare-calendar/calendar".freeze

    def initialize(flight_search)
      @flight_search = flight_search
    end

    def call
      Rails.logger.info "[Norwegian::PriceFetchService] Fetching prices for flight search ##{@flight_search.id}"

      flaresolverr = FlaresolverrService.new
      date_out = @flight_search.date_out
      date_in = @flight_search.date_in

      # Fetch calendar for outbound month
      begin
        outbound_response = flaresolverr.fetch(build_calendar_url(date_out.beginning_of_month))
      rescue FlaresolverrService::FlaresolverrError => e
        return update_with_error("FlareSolverr error: #{e.message}")
      end

      return update_with_error("Failed to fetch outbound calendar") unless outbound_response.is_a?(Hash)

      outbound_data = extract_price_for_date(outbound_response["outbound"], date_out)
      inbound_data = extract_price_for_date(outbound_response["inbound"], date_in)

      # If inbound date is in a different month, fetch that month's calendar
      if inbound_data.nil? && date_in.beginning_of_month != date_out.beginning_of_month
        Rails.logger.info "[Norwegian::PriceFetchService] Inbound date in different month, fetching #{date_in.beginning_of_month}"
        sleep 1 # Be polite

        begin
          inbound_response = flaresolverr.fetch(build_calendar_url(date_in.beginning_of_month))
        rescue FlaresolverrService::FlaresolverrError => e
          return update_with_error("FlareSolverr error fetching inbound: #{e.message}")
        end

        if inbound_response.is_a?(Hash)
          inbound_data = extract_price_for_date(inbound_response["inbound"], date_in)
        end
      end

      if outbound_data && inbound_data
        save_prices(outbound_data, inbound_data)
      else
        missing = []
        missing << "outbound" unless outbound_data
        missing << "inbound" unless inbound_data
        update_with_error("Could not extract prices for: #{missing.join(', ')}")
      end
    rescue StandardError => e
      Rails.logger.error "[Norwegian::PriceFetchService] Error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      update_with_error(e.message)
    end

    private

    def build_calendar_url(month_start)
      destination = @flight_search.norwegian_destination

      params = {
        "adultCount" => "1",
        "destinationAirportCode" => destination.code,
        "originAirportCode" => "RIX",
        "outboundDate" => month_start.strftime("%Y-%m-%d"),
        "inboundDate" => month_start.strftime("%Y-%m-%d"),
        "tripType" => "2",
        "currencyCode" => "EUR",
        "languageCode" => "en-BZ",
        "pageId" => "258774",
        "eventType" => "init"
      }

      uri = URI(FARE_CALENDAR_API)
      uri.query = URI.encode_www_form(params)
      uri.to_s
    end

    def extract_price_for_date(direction_data, target_date)
      return nil unless direction_data && direction_data["days"]

      days = direction_data["days"]
      target_date_str = target_date.strftime("%Y-%m-%d")

      day = days.find do |d|
        date_str = d["date"]
        next unless date_str.present?
        date_str.start_with?(target_date_str)
      end

      return nil unless day && day["price"].to_f > 0

      {
        price: day["price"].to_f,
        is_direct: day["transitCount"].to_i == 0
      }
    end

    def save_prices(outbound_data, inbound_data)
      new_total_price = outbound_data[:price] + inbound_data[:price]
      previous_total_price = @flight_search.total_price

      @flight_search.update!(
        price_out: outbound_data[:price],
        price_in: inbound_data[:price],
        is_direct_out: outbound_data[:is_direct],
        is_direct_in: inbound_data[:is_direct],
        status: "priced",
        priced_at: Time.current,
        api_response: { outbound: outbound_data, inbound: inbound_data }.to_json
      )

      # Record price history if price changed
      @flight_search.record_price_if_changed(outbound_data[:price], inbound_data[:price], new_total_price)

      Rails.logger.info "[Norwegian::PriceFetchService] Prices saved: OUT=#{outbound_data[:price]}, IN=#{inbound_data[:price]}, TOTAL=#{@flight_search.total_price}"

      result = { success: true, price_out: outbound_data[:price], price_in: inbound_data[:price], total: @flight_search.total_price }

      # Check for price drop
      if previous_total_price.present? && new_total_price < previous_total_price
        price_drop = previous_total_price - new_total_price
        result[:price_drop] = {
          flight_search_id: @flight_search.id,
          destination_name: @flight_search.norwegian_destination.name,
          destination_code: @flight_search.norwegian_destination.code,
          date_out: @flight_search.date_out,
          date_in: @flight_search.date_in,
          previous_price: previous_total_price,
          current_price: new_total_price,
          savings: price_drop
        }
        Rails.logger.info "[Norwegian::PriceFetchService] Price dropped by #{price_drop} EUR!"
      end

      result
    end

    def update_with_error(message)
      @flight_search.update!(status: "error", api_response: { error: message }.to_json)
      { success: false, error: message }
    end
  end
end
