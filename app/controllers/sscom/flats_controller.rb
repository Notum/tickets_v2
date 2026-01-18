module Sscom
  class FlatsController < ApplicationController
    include ActionView::RecordIdentifier

    def index
      @regions = SsRegion.ordered
      @followed_flats = current_user.ss_flat_follows.includes(:ss_flat_ad).active
      @deal_types = SsFlatAd::DEAL_TYPES
      @building_series = SsFlatAd::BUILDING_SERIES
    end

    def search
      region = SsRegion.find_by(id: params[:region_id])
      city = SsCity.find_by(id: params[:city_id]) if params[:city_id].present?
      deal_type = params[:deal_type].presence || "sell"

      filters = {
        rooms_min: params[:rooms_min].presence&.to_i,
        rooms_max: params[:rooms_max].presence&.to_i,
        area_min: params[:area_min].presence&.to_f,
        area_max: params[:area_max].presence&.to_f,
        floor_min: params[:floor_min].presence&.to_i,
        floor_max: params[:floor_max].presence&.to_i,
        price_min: params[:price_min].presence&.to_i,
        price_max: params[:price_max].presence&.to_i,
        building_series: params[:building_series].presence
      }.compact

      result = ::Sscom::FlatListingService.new(
        region: region,
        city: city,
        deal_type: deal_type,
        filters: filters
      ).call

      if result[:success]
        @ads = SsFlatAd.where(ss_region: region)
        @ads = @ads.where(ss_city: city) if city
        @ads = @ads.where(deal_type: deal_type)
        @ads = apply_filters(@ads, filters)
        @ads = @ads.active.recent.limit(100)

        # Mark which ads are already followed by user
        followed_ids = current_user.ss_flat_follows.pluck(:ss_flat_ad_id)
        @ads = @ads.map { |ad| { ad: ad, followed: followed_ids.include?(ad.id) } }

        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.replace("search-results", partial: "sscom/flats/results", locals: { ads: @ads }) }
          format.html { redirect_to sscom_flats_path }
        end
      else
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.replace("search-results", partial: "sscom/flats/error", locals: { error: result[:error] }) }
          format.html do
            flash[:alert] = result[:error]
            redirect_to sscom_flats_path
          end
        end
      end
    end

    def follow
      ad = SsFlatAd.find_by(id: params[:id])

      unless ad
        respond_with_error("Ad not found")
        return
      end

      follow = current_user.ss_flat_follows.find_or_initialize_by(ss_flat_ad: ad)

      if follow.persisted?
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.remove(dom_id(ad)) }
          format.html { redirect_to sscom_flats_path, notice: "You are already following this ad." }
        end
        return
      end

      if follow.save
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.remove(dom_id(ad)),
              turbo_stream.remove("followed-flats-empty"),
              turbo_stream.prepend("followed-flats", partial: "sscom/flats/followed_item", locals: { follow: follow, ad: ad })
            ]
          end
          format.html { redirect_to sscom_flats_path, notice: "Now following this ad." }
        end
      else
        respond_with_error(follow.errors.full_messages.join(", "))
      end
    end

    def unfollow
      follow = current_user.ss_flat_follows.find_by(ss_flat_ad_id: params[:id])

      if follow&.destroy
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.remove("follow_#{follow.id}") }
          format.html do
            flash[:notice] = "Stopped following this ad."
            redirect_to sscom_flats_path
          end
        end
      else
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.prepend("flash", partial: "shared/flash", locals: { type: "alert", message: "Could not unfollow ad." }) }
          format.html do
            flash[:alert] = "Could not unfollow ad."
            redirect_to sscom_flats_path
          end
        end
      end
    end

    private

    def apply_filters(scope, filters)
      scope = scope.where("rooms >= ?", filters[:rooms_min]) if filters[:rooms_min]
      scope = scope.where("rooms <= ?", filters[:rooms_max]) if filters[:rooms_max]
      scope = scope.where("area >= ?", filters[:area_min]) if filters[:area_min]
      scope = scope.where("area <= ?", filters[:area_max]) if filters[:area_max]
      scope = scope.where("floor_current >= ?", filters[:floor_min]) if filters[:floor_min]
      scope = scope.where("floor_current <= ?", filters[:floor_max]) if filters[:floor_max]
      scope = scope.where("price >= ?", filters[:price_min]) if filters[:price_min]
      scope = scope.where("price <= ?", filters[:price_max]) if filters[:price_max]
      scope = scope.where(building_series: filters[:building_series]) if filters[:building_series]
      scope
    end

    def respond_with_error(message)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.prepend("flash", partial: "shared/flash", locals: { type: "alert", message: message }) }
        format.html do
          flash[:alert] = message
          redirect_to sscom_flats_path
        end
      end
    end
  end
end
