module Api
  class BodeController < ApplicationController
    def destinations
      destinations = BodeDestination.ordered.map do |d|
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

      result = Bode::FlightsFetchService.new(destination).call

      if result[:success]
        flights = result[:flights].map do |f|
          {
            date_out: f[:date_out].strftime("%d.%m.%Y"),
            date_in: f[:date_in].strftime("%d.%m.%Y"),
            nights: f[:nights],
            price: f[:price],
            airline: f[:airline],
            free_seats: f[:free_seats],
            label: "#{f[:date_out].strftime('%d.%m.%Y')} - #{f[:date_in].strftime('%d.%m.%Y')} (#{f[:nights]}n) - #{f[:price]}€"
          }
        end

        render json: flights
      else
        render json: { error: result[:error] }, status: :unprocessable_entity
      end
    end
  end
end
