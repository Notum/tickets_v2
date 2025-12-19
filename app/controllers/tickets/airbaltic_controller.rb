module Tickets
  class AirbalticController < ApplicationController
    def index
      @destinations = AirbalticDestination.ordered
      @saved_searches = current_user.airbaltic_flight_searches.includes(:airbaltic_destination).recent
      @selected_destination_code = params[:destination_code] if params[:destination_code].present?
    end

    def create
      destination = AirbalticDestination.find_by(code: params[:destination_code])

      unless destination
        flash[:alert] = "Destination not found"
        redirect_to tickets_airbaltic_path and return
      end

      # Parse prices - handle empty strings as nil
      price_out = params[:price_out].present? ? params[:price_out].to_f : nil
      price_in = params[:price_in].present? ? params[:price_in].to_f : nil

      @flight_search = current_user.airbaltic_flight_searches.build(
        airbaltic_destination: destination,
        date_out: params[:date_out],
        date_in: params[:date_in],
        price_out: price_out,
        price_in: price_in,
        is_direct_out: params[:is_direct_out] == "true",
        is_direct_in: params[:is_direct_in] == "true"
      )

      if @flight_search.save
        # Record initial price history if we have prices
        if @flight_search.price_out.present? && @flight_search.price_in.present? &&
           @flight_search.price_out > 0 && @flight_search.price_in > 0
          @flight_search.update!(status: "priced", priced_at: Time.current)
          @flight_search.record_price_if_changed(@flight_search.price_out, @flight_search.price_in, @flight_search.total_price)
          flash[:notice] = "Flight search saved!"
        else
          # Queue price fetch job if prices not provided
          FetchAirbalticPriceJob.perform_later(@flight_search.id)
          flash[:notice] = "Flight search saved! Price will be fetched in the background."
        end

        redirect_to tickets_airbaltic_path(destination_code: destination.code)
      else
        flash[:alert] = @flight_search.errors.full_messages.join(", ")
        redirect_to tickets_airbaltic_path(destination_code: destination.code)
      end
    end

    def destroy
      @flight_search = current_user.airbaltic_flight_searches.find_by(id: params[:id])

      if @flight_search&.destroy
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.remove(@flight_search) }
          format.html do
            flash[:notice] = "Flight search deleted."
            redirect_to tickets_airbaltic_path
          end
        end
      else
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.prepend("flash", partial: "shared/flash", locals: { type: "alert", message: "Could not delete flight search." }) }
          format.html do
            flash[:alert] = "Could not delete flight search."
            redirect_to tickets_airbaltic_path
          end
        end
      end
    end

    def refresh_price
      @flight_search = current_user.airbaltic_flight_searches.find_by(id: params[:id])

      if @flight_search
        @flight_search.update!(status: "pending", price_out: nil, price_in: nil, total_price: nil)
        FetchAirbalticPriceJob.perform_later(@flight_search.id)
        flash[:notice] = "Price refresh queued."
      else
        flash[:alert] = "Flight search not found."
      end

      redirect_to tickets_airbaltic_path
    end
  end
end
