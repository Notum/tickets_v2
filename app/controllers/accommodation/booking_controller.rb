module Accommodation
  class BookingController < ApplicationController
    def index
      @saved_searches = current_user.booking_searches.recent
      @currency = current_user.currency
    end

    def create
      @booking_search = current_user.booking_searches.build(booking_search_params)
      @booking_search.currency = current_user.currency

      if @booking_search.save
        FetchBookingPriceJob.perform_later(@booking_search.id)
        flash[:notice] = "Hotel search saved! Prices will be fetched in the background."
        redirect_to accommodation_booking_path
      else
        flash[:alert] = @booking_search.errors.full_messages.join(", ")
        redirect_to accommodation_booking_path
      end
    end

    def destroy
      @booking_search = current_user.booking_searches.find_by(id: params[:id])

      if @booking_search&.destroy
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.remove(@booking_search) }
          format.html do
            flash[:notice] = "Hotel search deleted."
            redirect_to accommodation_booking_path
          end
        end
      else
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.prepend("flash", partial: "shared/flash", locals: { type: "alert", message: "Could not delete hotel search." }) }
          format.html do
            flash[:alert] = "Could not delete hotel search."
            redirect_to accommodation_booking_path
          end
        end
      end
    end

    def refresh_price
      @booking_search = current_user.booking_searches.find_by(id: params[:id])

      if @booking_search
        @booking_search.update!(status: "pending", price: nil, price_per_night: nil)
        FetchBookingPriceJob.perform_later(@booking_search.id)
        flash[:notice] = "Price refresh queued."
      else
        flash[:alert] = "Hotel search not found."
      end

      redirect_to accommodation_booking_path
    end

    private

    def booking_search_params
      params.permit(:city_name, :country_name, :hotel_id, :hotel_name, :hotel_url, :check_in, :check_out, :adults, :rooms, :room_id, :block_id, :room_name)
    end
  end
end
