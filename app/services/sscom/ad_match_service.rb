module Sscom
  class AdMatchService < BaseService
    # Matches ads by content hash when external_id changes (ad re-posted)
    # This preserves follows and price history across ad re-listings

    def initialize(ad_class:, external_id:, attributes:)
      @ad_class = ad_class # SsFlatAd or SsHouseAd
      @external_id = external_id
      @attributes = attributes
    end

    def call
      Rails.logger.info "[Sscom::AdMatchService] Matching ad #{@external_id} for #{@ad_class.name}"

      # First, try to find by exact external_id
      ad = @ad_class.find_by(external_id: @external_id)
      if ad
        Rails.logger.info "[Sscom::AdMatchService] Found exact match by external_id"
        return { success: true, ad: ad, match_type: :external_id }
      end

      # Generate content hash for matching
      content_hash = generate_hash_for_ad
      Rails.logger.info "[Sscom::AdMatchService] Generated content_hash: #{content_hash}"

      # Try to find by content hash within last 30 days
      ad = @ad_class.where(content_hash: content_hash)
                    .where("created_at > ?", 30.days.ago)
                    .order(created_at: :desc)
                    .first

      if ad
        Rails.logger.info "[Sscom::AdMatchService] Found match by content_hash (old external_id: #{ad.external_id})"

        # Update the external_id to the new one
        ad.update!(external_id: @external_id)

        return { success: true, ad: ad, match_type: :content_hash, previous_external_id: ad.external_id_before_last_save }
      end

      Rails.logger.info "[Sscom::AdMatchService] No match found"
      { success: false, ad: nil, match_type: :none }
    rescue StandardError => e
      Rails.logger.error "[Sscom::AdMatchService] Error: #{e.message}"
      { success: false, error: e.message }
    end

    private

    def generate_hash_for_ad
      if @ad_class == SsFlatAd
        generate_flat_hash
      else
        generate_house_hash
      end
    end

    def generate_flat_hash
      generate_content_hash([
        @attributes[:ss_region_id],
        @attributes[:ss_city_id],
        @attributes[:street]&.downcase&.strip,
        @attributes[:rooms],
        @attributes[:area]&.round(1),
        @attributes[:floor_current],
        @attributes[:floor_total],
        @attributes[:building_series]
      ])
    end

    def generate_house_hash
      generate_content_hash([
        @attributes[:ss_region_id],
        @attributes[:ss_city_id],
        @attributes[:street]&.downcase&.strip,
        @attributes[:rooms],
        @attributes[:area]&.round(1),
        @attributes[:land_area]&.round(1),
        @attributes[:floors],
        @attributes[:house_type]
      ])
    end
  end
end
