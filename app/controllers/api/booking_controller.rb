module Api
  class BookingController < ApplicationController
    def search_hotels
      city = params[:city]
      hotel_name = params[:hotel_name]
      check_in = params[:check_in]
      check_out = params[:check_out]
      adults = params[:adults] || 2
      rooms = params[:rooms] || 1
      currency = current_user.currency

      if city.blank? || hotel_name.blank? || check_in.blank? || check_out.blank?
        render json: { success: false, error: "Missing required parameters" } and return
      end

      result = Booking::HotelSearchService.new(
        city: city,
        hotel_name: hotel_name,
        check_in: Date.parse(check_in),
        check_out: Date.parse(check_out),
        adults: adults.to_i,
        rooms: rooms.to_i,
        currency: currency
      ).call

      render json: result
    rescue Date::Error => e
      render json: { success: false, error: "Invalid date format" }
    rescue StandardError => e
      Rails.logger.error "[Api::BookingController] Error: #{e.message}"
      render json: { success: false, error: e.message }
    end

    def fetch_rooms
      hotel_url = params[:hotel_url]
      check_in = params[:check_in]
      check_out = params[:check_out]
      adults = params[:adults] || 2
      rooms = params[:rooms] || 1
      currency = current_user.currency

      if hotel_url.blank? || check_in.blank? || check_out.blank?
        render json: { success: false, error: "Missing required parameters" } and return
      end

      result = Booking::RoomFetchService.new(
        hotel_url: hotel_url,
        check_in: Date.parse(check_in),
        check_out: Date.parse(check_out),
        adults: adults.to_i,
        rooms: rooms.to_i,
        currency: currency
      ).call

      render json: result
    rescue Date::Error => e
      render json: { success: false, error: "Invalid date format" }
    rescue StandardError => e
      Rails.logger.error "[Api::BookingController] fetch_rooms Error: #{e.message}"
      render json: { success: false, error: e.message }
    end
  end
end
