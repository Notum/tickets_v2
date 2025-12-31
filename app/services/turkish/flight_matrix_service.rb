require "net/http"
require "json"

module Turkish
  class FlightMatrixService
    FLIGHT_MATRIX_API = "https://www.turkishairlines.com/api/v1/availability/flight-matrix".freeze
    CACHE_EXPIRY = 6.hours

    # Origin is always Riga
    ORIGIN_CODE = "RIX".freeze
    ORIGIN_NAME = "Riga".freeze
    ORIGIN_COUNTRY_CODE = "LV".freeze

    def self.cache_key(destination_code, date_out, date_in)
      "turkish_flight_matrix_#{destination_code}_#{date_out}_#{date_in}"
    end

    def initialize(destination_code:, destination_name:, destination_city_code:, destination_country_code:, date_out:, date_in:)
      @destination_code = destination_code
      @destination_name = destination_name
      @destination_city_code = destination_city_code || destination_code
      @destination_country_code = destination_country_code
      @date_out = date_out
      @date_in = date_in
    end

    def call
      cache_key = self.class.cache_key(@destination_code, @date_out, @date_in)

      # Check cache first
      cached_result = Rails.cache.read(cache_key)
      if cached_result.present?
        Rails.logger.info "[Turkish::FlightMatrixService] Returning cached matrix for #{@destination_code}"
        return cached_result
      end

      Rails.logger.info "[Turkish::FlightMatrixService] Fetching flight matrix for #{@destination_code}, #{@date_out} - #{@date_in}"

      response = fetch_with_flaresolverr

      result = parse_matrix_response(response)

      # Cache successful results
      if result[:success] && result[:outbound_dates].any?
        Rails.cache.write(cache_key, result, expires_in: CACHE_EXPIRY)
        Rails.logger.info "[Turkish::FlightMatrixService] Cached #{result[:outbound_dates].count} outbound dates"
      end

      result
    rescue FlaresolverrService::FlaresolverrError => e
      Rails.logger.error "[Turkish::FlightMatrixService] FlareSolverr error: #{e.message}"
      # Fallback to direct request in development
      if Rails.env.development?
        Rails.logger.info "[Turkish::FlightMatrixService] Falling back to direct request"
        response = make_direct_request
        parse_matrix_response(response)
      else
        { success: false, error: "FlareSolverr error: #{e.message}" }
      end
    rescue StandardError => e
      Rails.logger.error "[Turkish::FlightMatrixService] Error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      { success: false, error: e.message }
    end

    private

    def fetch_with_flaresolverr
      Rails.logger.info "[Turkish::FlightMatrixService] Fetching via FlareSolverr POST to #{FLIGHT_MATRIX_API}"

      flaresolverr = FlaresolverrService.new
      headers = build_headers
      flaresolverr.post(FLIGHT_MATRIX_API, build_payload, headers: headers)
    end

    def build_headers
      conversation_id = SecureRandom.uuid
      {
        "Accept" => "application/json",
        "Accept-Language" => "en",
        "Content-Type" => "application/json",
        "Origin" => "https://www.turkishairlines.com",
        "Referer" => "https://www.turkishairlines.com/en-int/flights/booking/",
        "x-country" => "int",
        "x-platform" => "WEB",
        "x-clientid" => SecureRandom.uuid,
        "x-conversationid" => conversation_id,
        "x-requestid" => SecureRandom.uuid,
        "x-bfp" => SecureRandom.hex(16)
      }
    end

    def make_direct_request
      uri = URI(FLIGHT_MATRIX_API)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri.path)

      # Set headers to mimic browser request
      build_headers.each { |key, value| request[key] = value }
      request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

      request.body = build_payload.to_json

      Rails.logger.info "[Turkish::FlightMatrixService] Making direct POST to #{FLIGHT_MATRIX_API}"
      response = http.request(request)
      Rails.logger.info "[Turkish::FlightMatrixService] Response: #{response.code} (#{response.body.length} bytes)"

      if response.code.to_i == 200
        JSON.parse(response.body)
      else
        Rails.logger.warn "[Turkish::FlightMatrixService] HTTP #{response.code}: #{response.body.first(500)}"
        { "success" => false, "error" => "HTTP #{response.code}" }
      end
    end

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
            destinationAirportCode: @destination_code,
            destinationCityCode: @destination_city_code,
            destinationCity: @destination_name,
            destinationCountryCode: @destination_country_code,
            destinationMultiPort: false,
            destinationDomestic: false,
            departureDate: format_date(@date_out)
          },
          {
            originAirportCode: @destination_code,
            originCityCode: @destination_city_code,
            originCity: @destination_name,
            originCountryCode: @destination_country_code,
            originMultiPort: false,
            originDomestic: false,
            destinationAirportCode: ORIGIN_CODE,
            destinationCityCode: ORIGIN_CODE,
            destinationCity: ORIGIN_NAME,
            destinationCountryCode: ORIGIN_COUNTRY_CODE,
            destinationMultiPort: false,
            destinationDomestic: false,
            departureDate: format_date(@date_in)
          }
        ],
        savedDate: Time.current.iso8601(3),
        responsive: false
      }
    end

    def format_date(date)
      # Turkish Airlines expects DD-MM-YYYY format
      date = Date.parse(date.to_s) if date.is_a?(String)
      date.strftime("%d-%m-%Y")
    end

    def parse_matrix_response(response)
      unless response.is_a?(Hash) && response["success"] == true && response["data"]
        error_msg = response.is_a?(Hash) ? (response["message"] || response["error"] || "Unknown error") : "Invalid response"
        return { success: false, error: error_msg }
      end

      data = response["data"]

      outbound_dates = parse_date_list(data["outboundDateList"])
      inbound_dates = parse_date_list(data["inboundDateList"])
      price_matrix = parse_price_matrix(data["matrixPriceList"])

      {
        success: true,
        outbound_dates: outbound_dates,
        inbound_dates: inbound_dates,
        price_matrix: price_matrix
      }
    end

    def parse_date_list(date_list)
      return [] unless date_list.is_a?(Array)

      date_list.map do |date_str|
        # Parse DD-MM-YYYY format
        Date.strptime(date_str, "%d-%m-%Y")
      end.sort
    end

    def parse_price_matrix(matrix_list)
      return [] unless matrix_list.is_a?(Array)

      matrix_list.map do |item|
        {
          outbound_date: Date.strptime(item["outboundDate"], "%d-%m-%Y"),
          inbound_date: Date.strptime(item["inboundDate"], "%d-%m-%Y"),
          price: item.dig("price", "amount")&.to_f,
          currency: item.dig("price", "currencyCode"),
          best_price: item["bestPrice"] == true
        }
      end
    end
  end
end
