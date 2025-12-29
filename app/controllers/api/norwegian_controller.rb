module Api
  class NorwegianController < ApplicationController
    def destinations
      destinations = NorwegianDestination.active.ordered.map do |dest|
        {
          code: dest.code,
          name: dest.name,
          display_name: dest.display_name,
          country: dest.country_name
        }
      end

      render json: { destinations: destinations }
    end

    def dates_out
      destination_code = params[:destination_code]

      if destination_code.blank?
        render json: { error: "Destination code is required" }, status: :bad_request
        return
      end

      dates = Norwegian::OutboundDatesService.new(destination_code).call

      render json: {
        dates: dates.map { |d| { date: d[:date].to_s, is_direct: d[:is_direct] } }
      }
    end

    def dates_in
      destination_code = params[:destination_code]
      date_out = params[:date_out]

      if destination_code.blank?
        render json: { error: "Destination code is required" }, status: :bad_request
        return
      end

      if date_out.blank?
        render json: { error: "Outbound date is required" }, status: :bad_request
        return
      end

      dates = Norwegian::InboundDatesService.new(destination_code, date_out).call

      render json: {
        dates: dates.map { |d| { date: d[:date].to_s, is_direct: d[:is_direct] } }
      }
    end
  end
end
