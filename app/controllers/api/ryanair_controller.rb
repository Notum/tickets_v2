module Api
  class RyanairController < ApplicationController
    def destinations
      destinations = RyanairDestination.ordered.map do |dest|
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

      dates = Ryanair::OutboundDatesService.new(destination_code).call
      render json: { dates: dates.map(&:to_s) }
    end

    def dates_in
      destination_code = params[:destination_code]
      date_out = params[:date_out]

      if destination_code.blank?
        render json: { error: "Destination code is required" }, status: :bad_request
        return
      end

      dates = Ryanair::ReturnDatesService.new(destination_code).call

      # Filter to only dates after date_out if provided
      if date_out.present?
        date_out_parsed = Date.parse(date_out) rescue nil
        dates = dates.select { |d| d > date_out_parsed } if date_out_parsed
      end

      render json: { dates: dates.map(&:to_s) }
    end

    def flight_searches
      destination = RyanairDestination.find_by(code: params[:destination_code])

      unless destination
        render json: { error: "Destination not found" }, status: :not_found
        return
      end

      flight_search = current_user.ryanair_flight_searches.build(
        ryanair_destination: destination,
        date_out: params[:date_out],
        date_in: params[:date_in]
      )

      if flight_search.save
        FetchRyanairPriceJob.perform_later(flight_search.id)
        render json: {
          success: true,
          flight_search: {
            id: flight_search.id,
            destination: destination.display_name,
            date_out: flight_search.date_out,
            date_in: flight_search.date_in,
            status: flight_search.status
          }
        }
      else
        render json: { error: flight_search.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end
    end
  end
end
