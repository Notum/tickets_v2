module Tickets
  class RyanairController < ApplicationController
    def index
      @destinations = RyanairDestination.ordered
      @saved_searches = current_user.ryanair_flight_searches.includes(:ryanair_destination).recent
    end

    def create
      destination = RyanairDestination.find_by(code: params[:destination_code])

      unless destination
        flash[:alert] = "Destination not found"
        redirect_to tickets_ryanair_path and return
      end

      @flight_search = current_user.ryanair_flight_searches.build(
        ryanair_destination: destination,
        date_out: params[:date_out],
        date_in: params[:date_in]
      )

      if @flight_search.save
        # Queue price fetch job
        FetchRyanairPriceJob.perform_later(@flight_search.id)

        flash[:notice] = "Flight search saved! Prices will be fetched in the background."
        redirect_to tickets_ryanair_path
      else
        flash[:alert] = @flight_search.errors.full_messages.join(", ")
        redirect_to tickets_ryanair_path
      end
    end

    def destroy
      @flight_search = current_user.ryanair_flight_searches.find_by(id: params[:id])

      if @flight_search&.destroy
        flash[:notice] = "Flight search deleted."
      else
        flash[:alert] = "Could not delete flight search."
      end

      redirect_to tickets_ryanair_path
    end

    def refresh_price
      @flight_search = current_user.ryanair_flight_searches.find_by(id: params[:id])

      if @flight_search
        @flight_search.update!(status: "pending", price_out: nil, price_in: nil, total_price: nil)
        FetchRyanairPriceJob.perform_later(@flight_search.id)
        flash[:notice] = "Price refresh queued."
      else
        flash[:alert] = "Flight search not found."
      end

      redirect_to tickets_ryanair_path
    end
  end
end
