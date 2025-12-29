require "net/http"
require "json"

module Turkish
  class PriceFetchService
    FLIGHT_MATRIX_API = "https://www.turkishairlines.com/api/v1/availability/flight-matrix".freeze

    # Origin is always Riga
    ORIGIN_CODE = "RIX".freeze
    ORIGIN_NAME = "Riga".freeze
    ORIGIN_COUNTRY_CODE = "LV".freeze

    def initialize(flight_search)
      @flight_search = flight_search
    end

    def call
      Rails.logger.info "[Turkish::PriceFetchService] Fetching prices for flight search ##{@flight_search.id}"

      payload = build_payload

      begin
        response = make_direct_request(payload)
      rescue StandardError => e
        return update_with_error("Request error: #{e.message}")
      end

      # Save raw response for debugging (truncate to avoid huge data)
      @flight_search.update!(api_response: response.to_json.first(10000))

      price_data = extract_price(response)

      if price_data
        save_prices(price_data)
      else
        update_with_error("No flights available for this route and dates")
      end
    rescue StandardError => e
      Rails.logger.error "[Turkish::PriceFetchService] Error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      update_with_error(e.message)
    end

    private

    def build_payload
      {
        selectedBookerSearch: "R",
        selectedCabinClass: "ECONOMY",
        moduleType: "TICKETING",
        passengerTypeList: [ { quantity: 1, code: "ADULT" } ],
        originDestinationInformationList: [
          {
            originAirportCode: ORIGIN_CODE,
            originCityCode: ORIGIN_CODE,
            originCity: ORIGIN_NAME,
            originCountryCode: ORIGIN_COUNTRY_CODE,
            originMultiPort: false,
            originDomestic: false,
            destinationAirportCode: @flight_search.destination_code,
            destinationCityCode: @flight_search.destination_city_code || @flight_search.destination_code,
            destinationCity: @flight_search.destination_name,
            destinationCountryCode: @flight_search.destination_country_code,
            destinationMultiPort: false,
            destinationDomestic: false,
            departureDate: format_date(@flight_search.date_out)
          },
          {
            originAirportCode: @flight_search.destination_code,
            originCityCode: @flight_search.destination_city_code || @flight_search.destination_code,
            originCity: @flight_search.destination_name,
            originCountryCode: @flight_search.destination_country_code,
            originMultiPort: false,
            originDomestic: false,
            destinationAirportCode: ORIGIN_CODE,
            destinationCityCode: ORIGIN_CODE,
            destinationCity: ORIGIN_NAME,
            destinationCountryCode: ORIGIN_COUNTRY_CODE,
            destinationMultiPort: false,
            destinationDomestic: false,
            departureDate: format_date(@flight_search.date_in)
          }
        ],
        savedDate: Time.current.iso8601(3),
        responsive: false
      }
    end

    def format_date(date)
      # Turkish Airlines expects DD-MM-YYYY format
      date.strftime("%d-%m-%Y")
    end

    def make_direct_request(payload)
      uri = URI(FLIGHT_MATRIX_API)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri.path)

      # Set headers to mimic browser request
      conversation_id = SecureRandom.uuid
      request["Accept"] = "application/json"
      request["Accept-Language"] = "en"
      request["Content-Type"] = "application/json"
      request["Origin"] = "https://www.turkishairlines.com"
      request["Referer"] = "https://www.turkishairlines.com/en-int/flights/booking/"
      request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
      request["x-country"] = "int"
      request["x-platform"] = "WEB"
      request["x-clientid"] = SecureRandom.uuid
      request["x-conversationid"] = conversation_id
      request["x-requestid"] = SecureRandom.uuid
      request["x-bfp"] = SecureRandom.hex(16)

      request.body = payload.to_json

      Rails.logger.info "[Turkish::PriceFetchService] Making direct POST to #{FLIGHT_MATRIX_API}"
      response = http.request(request)
      Rails.logger.info "[Turkish::PriceFetchService] Response: #{response.code} (#{response.body.length} bytes)"

      if response.code.to_i == 200
        JSON.parse(response.body)
      else
        Rails.logger.warn "[Turkish::PriceFetchService] HTTP #{response.code}: #{response.body.first(500)}"
        { "success" => false, "error" => "HTTP #{response.code}" }
      end
    end

    def extract_price(response)
      unless response.is_a?(Hash) && response["success"] == true && response["data"]
        Rails.logger.warn "[Turkish::PriceFetchService] Invalid response structure"
        Rails.logger.warn "[Turkish::PriceFetchService] Response: #{response.inspect.first(500)}"
        return nil
      end

      data = response["data"]
      matrix_list = data["matrixPriceList"]

      unless matrix_list.is_a?(Array) && matrix_list.any?
        Rails.logger.warn "[Turkish::PriceFetchService] No price matrix in response"
        return nil
      end

      # Find the exact date match in the matrix
      target_out = format_date(@flight_search.date_out)
      target_in = format_date(@flight_search.date_in)

      price_entry = matrix_list.find do |entry|
        entry["outboundDate"] == target_out && entry["inboundDate"] == target_in
      end

      unless price_entry
        Rails.logger.warn "[Turkish::PriceFetchService] No matching dates found in matrix (looking for #{target_out} -> #{target_in})"
        # Log available dates for debugging
        available = matrix_list.map { |e| "#{e['outboundDate']}/#{e['inboundDate']}" }.first(5)
        Rails.logger.info "[Turkish::PriceFetchService] Available date pairs (first 5): #{available.join(', ')}"
        return nil
      end

      total_price = price_entry.dig("price", "amount")&.to_f

      unless total_price && total_price > 0
        Rails.logger.warn "[Turkish::PriceFetchService] Invalid price in matrix entry"
        return nil
      end

      Rails.logger.info "[Turkish::PriceFetchService] Found price: #{total_price} EUR (bestPrice: #{price_entry['bestPrice']})"

      {
        total: total_price,
        # Flight-matrix returns total price only, not split by direction
        # We'll estimate 50/50 split for display purposes
        price_out: (total_price / 2).round(2),
        price_in: (total_price / 2).round(2)
      }
    end

    def save_prices(price_data)
      new_total_price = price_data[:total]
      previous_total_price = @flight_search.total_price

      @flight_search.update!(
        price_out: price_data[:price_out],
        price_in: price_data[:price_in],
        is_direct_out: false,  # Always 1-stop via Istanbul
        is_direct_in: false,
        status: "priced",
        priced_at: Time.current
      )

      # Record price history if price changed
      @flight_search.record_price_if_changed(price_data[:price_out], price_data[:price_in], new_total_price)

      Rails.logger.info "[Turkish::PriceFetchService] Prices saved: TOTAL=#{new_total_price}"

      result = { success: true, price_out: price_data[:price_out], price_in: price_data[:price_in], total: new_total_price }

      # Check for price drop
      if previous_total_price.present? && new_total_price < previous_total_price
        price_drop = previous_total_price - new_total_price
        result[:price_drop] = {
          flight_search_id: @flight_search.id,
          destination_name: @flight_search.destination_name,
          destination_code: @flight_search.destination_code,
          date_out: @flight_search.date_out,
          date_in: @flight_search.date_in,
          previous_price: previous_total_price,
          current_price: new_total_price,
          savings: price_drop
        }
        Rails.logger.info "[Turkish::PriceFetchService] Price dropped by #{price_drop} EUR!"
      end

      result
    end

    def update_with_error(message)
      @flight_search.update!(status: "error")
      Rails.logger.error "[Turkish::PriceFetchService] Error: #{message}"
      { success: false, error: message }
    end
  end
end
