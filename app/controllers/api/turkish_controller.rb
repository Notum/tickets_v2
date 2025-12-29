module Api
  class TurkishController < ApplicationController
    def destinations
      query = params[:query]

      if query.blank? || query.length < 2
        render json: { destinations: [] }
        return
      end

      destinations = Turkish::DestinationsSearchService.new(query).call

      render json: {
        destinations: destinations.map do |d|
          {
            code: d[:code],
            name: d[:name],
            city_code: d[:city_code],
            country_code: d[:country_code],
            display_name: "#{d[:name]} (#{d[:code]})"
          }
        end
      }
    end

    def flight_matrix
      destination_code = params[:destination_code]
      destination_name = params[:destination_name]
      destination_city_code = params[:destination_city_code]
      destination_country_code = params[:destination_country_code]
      date_out = params[:date_out]
      date_in = params[:date_in]

      if destination_code.blank?
        render json: { error: "Destination code is required" }, status: :bad_request
        return
      end

      # Set default dates if not provided (1 month from now, 2 weeks trip)
      date_out ||= (Date.current + 1.month).to_s
      date_in ||= (Date.current + 1.month + 14.days).to_s

      result = Turkish::FlightMatrixService.new(
        destination_code: destination_code,
        destination_name: destination_name || destination_code,
        destination_city_code: destination_city_code || destination_code,
        destination_country_code: destination_country_code || "XX",
        date_out: date_out,
        date_in: date_in
      ).call

      if result[:success]
        render json: {
          outbound_dates: result[:outbound_dates].map { |d| d.to_s },
          inbound_dates: result[:inbound_dates].map { |d| d.to_s },
          price_matrix: result[:price_matrix].map do |p|
            {
              outbound_date: p[:outbound_date].to_s,
              inbound_date: p[:inbound_date].to_s,
              price: p[:price],
              best_price: p[:best_price]
            }
          end
        }
      else
        render json: { error: result[:error] || "Failed to fetch flight matrix" }, status: :unprocessable_entity
      end
    end
  end
end
