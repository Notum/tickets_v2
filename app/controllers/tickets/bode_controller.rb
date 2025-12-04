module Tickets
  class BodeController < ApplicationController
    def index
      @destinations = BodeDestination.ordered
      @saved_searches = current_user.bode_flight_searches.includes(:bode_destination).recent
    end

    def create
      destination = BodeDestination.find_by(id: params[:destination_id])

      unless destination
        flash[:alert] = "Destination not found"
        redirect_to tickets_bode_path and return
      end

      # Parse dates from form
      date_out = parse_date(params[:date_out])
      date_in = parse_date(params[:date_in])

      unless date_out && date_in
        flash[:alert] = "Invalid dates provided"
        redirect_to tickets_bode_path and return
      end

      @flight_search = current_user.bode_flight_searches.build(
        bode_destination: destination,
        date_out: date_out,
        date_in: date_in
      )

      if @flight_search.save
        flash[:notice] = "Flight search saved! Prices will be updated on the next scheduled refresh."
        redirect_to tickets_bode_path
      else
        flash[:alert] = @flight_search.errors.full_messages.join(", ")
        redirect_to tickets_bode_path
      end
    end

    def destroy
      @flight_search = current_user.bode_flight_searches.find_by(id: params[:id])

      if @flight_search&.destroy
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.remove(@flight_search) }
          format.html do
            flash[:notice] = "Flight search deleted."
            redirect_to tickets_bode_path
          end
        end
      else
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.prepend("flash", partial: "shared/flash", locals: { type: "alert", message: "Could not delete flight search." }) }
          format.html do
            flash[:alert] = "Could not delete flight search."
            redirect_to tickets_bode_path
          end
        end
      end
    end

    private

    def parse_date(date_string)
      return nil if date_string.blank?

      # Handle DD.MM.YYYY format
      if date_string.match?(/^\d{2}\.\d{2}\.\d{4}$/)
        parts = date_string.split(".")
        Date.new(parts[2].to_i, parts[1].to_i, parts[0].to_i)
      else
        Date.parse(date_string)
      end
    rescue ArgumentError
      nil
    end
  end
end
