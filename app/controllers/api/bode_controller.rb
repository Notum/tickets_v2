module Api
  class BodeController < ApplicationController
    def destinations
      destinations = BodeDestination.active.ordered.map do |d|
        { id: d.id, name: d.display_name, charter_path: d.charter_path }
      end

      render json: destinations
    end

    def flights
      destination = BodeDestination.find_by(id: params[:destination_id])

      unless destination
        render json: { error: "Destination not found" }, status: :not_found
        return
      end

      flights = destination.bode_flights.future.by_departure.map do |f|
        {
          id: f.id,
          date_out: f.date_out.strftime("%d.%m.%Y"),
          date_in: f.date_in.strftime("%d.%m.%Y"),
          date_out_iso: f.date_out.iso8601,
          nights: f.nights,
          price: f.price.to_f,
          airline: f.airline,
          free_seats: f.free_seats,
          label: "#{f.date_out.strftime('%d.%m.%Y')} - #{f.date_in.strftime('%d.%m.%Y')} (#{f.nights}n) - #{f.price.to_i}€"
        }
      end

      render json: flights
    end
  end
end
