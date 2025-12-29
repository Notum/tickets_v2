module Api
  class FlydubaiController < ApplicationController
    def dates_out
      dates = Flydubai::OutboundDatesService.new.call

      render json: {
        dates: dates.map { |d| { date: d[:date].to_s, is_direct: d[:is_direct] } }
      }
    end

    def dates_in
      date_out = params[:date_out]

      if date_out.blank?
        render json: { error: "Outbound date is required" }, status: :bad_request
        return
      end

      dates = Flydubai::InboundDatesService.new(date_out).call

      render json: {
        dates: dates.map { |d| { date: d[:date].to_s, is_direct: d[:is_direct] } }
      }
    end
  end
end
