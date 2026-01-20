module Sscom
  class HousesController < ApplicationController
    include ActionView::RecordIdentifier

    def index
      @regions = SsRegion.ordered
      @followed_houses = current_user.ss_house_follows.includes(:ss_house_ad).active
      @deal_types = SsHouseAd::DEAL_TYPES
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
        land_area_min: params[:land_area_min].presence&.to_f,
        land_area_max: params[:land_area_max].presence&.to_f,
        floors_min: params[:floors_min].presence&.to_i,
        floors_max: params[:floors_max].presence&.to_i,
        price_min: params[:price_min].presence&.to_i,
        price_max: params[:price_max].presence&.to_i
      }.compact

      result = ::Sscom::HouseListingService.new(
        region: region,
        city: city,
        deal_type: deal_type,
        filters: filters
      ).call

      if result[:success]
        @ads = SsHouseAd.where(ss_region: region)
        @ads = @ads.where(ss_city: city) if city
        @ads = @ads.where(deal_type: deal_type)
        @ads = apply_filters(@ads, filters)
        @ads = @ads.active.recent.limit(100)

        # Mark which ads are already followed by user
        followed_ids = current_user.ss_house_follows.pluck(:ss_house_ad_id)
        @ads = @ads.map { |ad| { ad: ad, followed: followed_ids.include?(ad.id) } }

        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.replace("search-results", partial: "sscom/houses/results", locals: { ads: @ads }) }
          format.html { redirect_to sscom_houses_path }
        end
      else
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.replace("search-results", partial: "sscom/houses/error", locals: { error: result[:error] }) }
          format.html do
            flash[:alert] = result[:error]
            redirect_to sscom_houses_path
          end
        end
      end
    end

    def follow
      ad = SsHouseAd.find_by(id: params[:id])

      unless ad
        respond_with_error("Ad not found")
        return
      end

      follow = current_user.ss_house_follows.find_or_initialize_by(ss_house_ad: ad)

      if follow.persisted?
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.remove(dom_id(ad)) }
          format.html { redirect_to sscom_houses_path, notice: "You are already following this ad." }
        end
        return
      end

      if follow.save
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.remove(dom_id(ad)),
              turbo_stream.remove("followed-houses-empty"),
              turbo_stream.prepend("followed-houses", partial: "sscom/houses/followed_item", locals: { follow: follow, ad: ad })
            ]
          end
          format.html { redirect_to sscom_houses_path, notice: "Now following this ad." }
        end
      else
        respond_with_error(follow.errors.full_messages.join(", "))
      end
    end

    def unfollow
      follow = current_user.ss_house_follows.find_by(ss_house_ad_id: params[:id])

      if follow&.destroy
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.remove("follow_#{follow.id}") }
          format.html do
            flash[:notice] = "Stopped following this ad."
            redirect_to sscom_houses_path
          end
        end
      else
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.prepend("flash", partial: "shared/flash", locals: { type: "alert", message: "Could not unfollow ad." }) }
          format.html do
            flash[:alert] = "Could not unfollow ad."
            redirect_to sscom_houses_path
          end
        end
      end
    end

    def follow_by_url
      url = params[:url].to_s.strip

      if url.blank?
        respond_with_error("Please enter a valid SS.COM URL")
        return
      end

      # Validate that URL is for houses
      unless url.match?(%r{ss\.com/msg/[a-z]{2}/real-estate/homes-summer-residences/}i)
        respond_with_error("Please enter a URL for a house listing (not flats)")
        return
      end

      result = ::Sscom::AdFetchService.new(url: url).call

      unless result[:success]
        respond_with_error(result[:error])
        return
      end

      ad = result[:ad]

      # Check if already following
      existing_follow = current_user.ss_house_follows.find_by(ss_house_ad: ad)
      if existing_follow
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.prepend("flash", partial: "shared/flash", locals: { type: "info", message: "You are already following this ad." })
          end
          format.html { redirect_to sscom_houses_path, notice: "You are already following this ad." }
        end
        return
      end

      # Create the follow
      follow = current_user.ss_house_follows.build(ss_house_ad: ad)

      if follow.save
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.remove("followed-houses-empty"),
              turbo_stream.prepend("followed-houses", partial: "sscom/houses/followed_item", locals: { follow: follow, ad: ad }),
              turbo_stream.prepend("flash", partial: "shared/flash", locals: { type: "success", message: "Now following this ad." }),
              turbo_stream.replace("house-url-input", "<input type=\"text\" name=\"url\" id=\"house-url-input\" placeholder=\"https://www.ss.com/msg/ru/real-estate/homes-summer-residences/...\" class=\"input input-bordered w-full\" required>")
            ]
          end
          format.html { redirect_to sscom_houses_path, notice: "Now following this ad." }
        end
      else
        respond_with_error(follow.errors.full_messages.join(", "))
      end
    end

    private

    def apply_filters(scope, filters)
      scope = scope.where("rooms >= ?", filters[:rooms_min]) if filters[:rooms_min]
      scope = scope.where("rooms <= ?", filters[:rooms_max]) if filters[:rooms_max]
      scope = scope.where("area >= ?", filters[:area_min]) if filters[:area_min]
      scope = scope.where("area <= ?", filters[:area_max]) if filters[:area_max]
      scope = scope.where("land_area >= ?", filters[:land_area_min]) if filters[:land_area_min]
      scope = scope.where("land_area <= ?", filters[:land_area_max]) if filters[:land_area_max]
      scope = scope.where("floors >= ?", filters[:floors_min]) if filters[:floors_min]
      scope = scope.where("floors <= ?", filters[:floors_max]) if filters[:floors_max]
      scope = scope.where("price >= ?", filters[:price_min]) if filters[:price_min]
      scope = scope.where("price <= ?", filters[:price_max]) if filters[:price_max]
      scope
    end

    def respond_with_error(message)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.prepend("flash", partial: "shared/flash", locals: { type: "alert", message: message }) }
        format.html do
          flash[:alert] = message
          redirect_to sscom_houses_path
        end
      end
    end
  end
end
