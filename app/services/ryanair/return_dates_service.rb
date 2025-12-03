require "net/http"
require "json"

module Ryanair
  class ReturnDatesService
    BASE_URL = "https://www.ryanair.com/api/farfnd/3/oneWayFares".freeze

    def initialize(destination_code)
      @destination_code = destination_code
    end

    def call
      Rails.logger.info "[Ryanair::ReturnDatesService] Fetching return dates #{@destination_code} -> RIX"

      response = fetch_dates
      return [] unless response

      parse_dates(response)
    rescue StandardError => e
      Rails.logger.error "[Ryanair::ReturnDatesService] Error: #{e.message}"
      []
    end

    private

    def fetch_dates
      uri = URI("#{BASE_URL}/#{@destination_code}/RIX/availabilities")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"
      request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"

      response = http.request(request)

      if response.code == "200"
        JSON.parse(response.body)
      else
        Rails.logger.error "[Ryanair::ReturnDatesService] API returned #{response.code}"
        nil
      end
    end

    def parse_dates(data)
      return [] unless data.is_a?(Array)

      data.map { |date_str| Date.parse(date_str) rescue nil }.compact.sort
    end
  end
end
