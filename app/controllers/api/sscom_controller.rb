module Api
  class SscomController < ApplicationController
    def regions
      regions = SsRegion.ordered.select(:id, :slug, :name_lv, :name_ru)
      render json: { success: true, regions: regions }
    end

    def cities
      region = SsRegion.find_by(id: params[:region_id])

      unless region
        render json: { success: false, error: "Region not found" } and return
      end

      cities = region.ss_cities.ordered.select(:id, :slug, :name_lv, :name_ru)
      render json: { success: true, cities: cities }
    end

    def search_flats
      region = SsRegion.find_by(id: params[:region_id])

      unless region
        render json: { success: false, error: "Region is required" } and return
      end

      city = params[:city_id].present? ? SsCity.find_by(id: params[:city_id]) : nil
      deal_type = params[:deal_type].presence || "sell"

      filters = build_filters(params)

      result = ::Sscom::FlatListingService.new(
        region: region,
        city: city,
        deal_type: deal_type,
        filters: filters
      ).call

      if result[:success]
        ads = fetch_flat_ads(region, city, deal_type, filters)
        followed_ids = current_user.ss_flat_follows.pluck(:ss_flat_ad_id)

        render json: {
          success: true,
          total: result[:total],
          ads: ads.map { |ad| serialize_flat_ad(ad, followed_ids.include?(ad.id)) }
        }
      else
        render json: result
      end
    rescue StandardError => e
      Rails.logger.error "[Api::SscomController] search_flats Error: #{e.message}"
      render json: { success: false, error: e.message }
    end

    def search_houses
      region = SsRegion.find_by(id: params[:region_id])

      unless region
        render json: { success: false, error: "Region is required" } and return
      end

      city = params[:city_id].present? ? SsCity.find_by(id: params[:city_id]) : nil
      deal_type = params[:deal_type].presence || "sell"

      filters = build_house_filters(params)

      result = ::Sscom::HouseListingService.new(
        region: region,
        city: city,
        deal_type: deal_type,
        filters: filters
      ).call

      if result[:success]
        ads = fetch_house_ads(region, city, deal_type, filters)
        followed_ids = current_user.ss_house_follows.pluck(:ss_house_ad_id)

        render json: {
          success: true,
          total: result[:total],
          ads: ads.map { |ad| serialize_house_ad(ad, followed_ids.include?(ad.id)) }
        }
      else
        render json: result
      end
    rescue StandardError => e
      Rails.logger.error "[Api::SscomController] search_houses Error: #{e.message}"
      render json: { success: false, error: e.message }
    end

    private

    def build_filters(params)
      {
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
    end

    def build_house_filters(params)
      {
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
    end

    def fetch_flat_ads(region, city, deal_type, filters)
      ads = SsFlatAd.where(ss_region: region)
      ads = ads.where(ss_city: city) if city
      ads = ads.where(deal_type: deal_type)
      ads = apply_flat_filters(ads, filters)
      ads.active.recent.limit(100)
    end

    def fetch_house_ads(region, city, deal_type, filters)
      ads = SsHouseAd.where(ss_region: region)
      ads = ads.where(ss_city: city) if city
      ads = ads.where(deal_type: deal_type)
      ads = apply_house_filters(ads, filters)
      ads.active.recent.limit(100)
    end

    def apply_flat_filters(scope, filters)
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

    def apply_house_filters(scope, filters)
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

    def serialize_flat_ad(ad, followed)
      {
        id: ad.id,
        external_id: ad.external_id,
        title: ad.display_title,
        location: ad.location_display,
        rooms: ad.rooms,
        area: ad.area,
        floor: ad.floor_display,
        building_series: ad.building_series,
        price: ad.price,
        price_per_m2: ad.price_per_m2,
        thumbnail_url: ad.thumbnail_url,
        original_url: ad.original_url,
        posted_at: ad.posted_at,
        followed: followed
      }
    end

    def serialize_house_ad(ad, followed)
      {
        id: ad.id,
        external_id: ad.external_id,
        title: ad.display_title,
        location: ad.location_display,
        rooms: ad.rooms,
        area: ad.area,
        land_area: ad.land_area,
        floors: ad.floors,
        house_type: ad.house_type,
        price: ad.price,
        price_per_m2: ad.price_per_m2,
        thumbnail_url: ad.thumbnail_url,
        original_url: ad.original_url,
        posted_at: ad.posted_at,
        followed: followed
      }
    end
  end
end
