module Sscom
  class HouseListingService < BaseService
    # Deal type URL segments on SS.COM
    DEAL_TYPES = {
      "sell" => "sell",
      "buy" => "buy",
      "rent_out" => "hand_over",
      "rent_want" => "wanted",
      "exchange" => "exchange"
    }.freeze

    def initialize(region: nil, city: nil, deal_type: "sell", filters: {})
      @region = region
      @city = city
      @deal_type = deal_type
      @filters = filters
    end

    def call
      Rails.logger.info "[Sscom::HouseListingService] Fetching houses for region=#{@region&.slug}, city=#{@city&.slug}, deal_type=#{@deal_type}"

      unless @region
        return { success: false, error: "Region is required" }
      end

      url = build_listing_url
      Rails.logger.info "[Sscom::HouseListingService] URL: #{url}"

      html = fetch_page(url)
      return { success: false, error: "Failed to fetch listings page" } unless html

      doc = parse_html(html)
      return { success: false, error: "Failed to parse HTML" } unless doc

      ads = parse_listings(doc)
      Rails.logger.info "[Sscom::HouseListingService] Found #{ads.count} house ads"

      saved_count = save_ads(ads)

      {
        success: true,
        total: ads.count,
        saved: saved_count,
        ads: ads
      }
    rescue StandardError => e
      Rails.logger.error "[Sscom::HouseListingService] Error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      { success: false, error: e.message }
    end

    private

    def build_listing_url
      # Houses are under homes-summer-residences on SS.COM
      base = "/lv/real-estate/homes-summer-residences"
      path_parts = [base, @region.slug]
      path_parts << @city.slug if @city
      path_parts << DEAL_TYPES[@deal_type] || "sell"

      url = "#{path_parts.join("/")}/"

      # Add filter parameters
      params = build_filter_params
      url += "?#{URI.encode_www_form(params)}" if params.any?

      url
    end

    def build_filter_params
      params = {}

      # Room filter
      if @filters[:rooms_min] || @filters[:rooms_max]
        params["topt[1][min]"] = @filters[:rooms_min] if @filters[:rooms_min]
        params["topt[1][max]"] = @filters[:rooms_max] if @filters[:rooms_max]
      end

      # Living area filter (m2)
      if @filters[:area_min] || @filters[:area_max]
        params["topt[3][min]"] = @filters[:area_min] if @filters[:area_min]
        params["topt[3][max]"] = @filters[:area_max] if @filters[:area_max]
      end

      # Land area filter (m2)
      if @filters[:land_area_min] || @filters[:land_area_max]
        params["topt[5][min]"] = @filters[:land_area_min] if @filters[:land_area_min]
        params["topt[5][max]"] = @filters[:land_area_max] if @filters[:land_area_max]
      end

      # Floors filter
      if @filters[:floors_min] || @filters[:floors_max]
        params["topt[4][min]"] = @filters[:floors_min] if @filters[:floors_min]
        params["topt[4][max]"] = @filters[:floors_max] if @filters[:floors_max]
      end

      # Price filter
      if @filters[:price_min] || @filters[:price_max]
        params["topt[8][min]"] = @filters[:price_min] if @filters[:price_min]
        params["topt[8][max]"] = @filters[:price_max] if @filters[:price_max]
      end

      params
    end

    def parse_listings(doc)
      ads = []

      # SS.COM listings are in table rows with id prefix
      doc.css("tr[id^='tr_']").each do |row|
        ad = parse_ad_row(row)
        ads << ad if ad
      end

      # Alternative: look for listing items in a different structure
      if ads.empty?
        doc.css(".msg2, .msga2").each do |row|
          ad = parse_ad_row(row)
          ads << ad if ad
        end
      end

      ads
    end

    def parse_ad_row(row)
      # Extract ad ID from row id (e.g., "tr_12345678")
      row_id = row["id"].to_s
      external_id = row_id.gsub("tr_", "")
      return nil if external_id.blank?

      # Find the ad link
      link = row.at_css('a[href*="/msg/"]')
      return nil unless link

      href = link["href"].to_s
      original_url = href.start_with?("http") ? href : "#{BASE_URL}#{href}"

      # Extract thumbnail
      img = row.at_css("img")
      thumbnail_url = img["src"] if img

      # Parse table cells for data
      cells = row.css("td")

      title = clean_text(link.text)

      rooms = nil
      area = nil
      land_area = nil
      floors = nil
      street = nil
      house_type = nil
      price = nil
      price_per_m2 = nil

      cells.each_with_index do |cell, idx|
        text = clean_text(cell.text)
        next if text.blank?

        # Check for room count
        if text.match?(/^\d$/) && rooms.nil?
          rooms = text.to_i
        # Check for area (m2)
        elsif text.match?(/^\d+(?:[.,]\d+)?$/) && area.nil? && rooms.present?
          area = extract_number(text)
        # Check for land area (usually larger number)
        elsif text.match?(/^\d+(?:[.,]\d+)?$/) && area.present? && land_area.nil?
          land_area = extract_number(text)
        # Check for floors
        elsif text.match?(/^\d$/) && floors.nil? && area.present?
          floors = text.to_i
        # Check for price
        elsif text.match?(/[\d\s,]+\s*€/) || (text.gsub(/\s/, "").match?(/^\d{4,}$/) && price.nil?)
          price = extract_number(text)
        # Check for price per m2
        elsif text.match?(/[\d\s,]+\s*€\/m/)
          price_per_m2 = extract_number(text)
        # House type (common patterns)
        elsif text.match?(/^(māja|villa|kotedža|duplex|ferma)/i)
          house_type = text
        # Street/location
        elsif text.length > 5 && street.nil? && !text.match?(/^\d/)
          street = text
        end
      end

      # Skip if we couldn't extract essential data
      return nil unless price || rooms || area

      {
        external_id: external_id,
        ss_region_id: @region.id,
        ss_city_id: @city&.id,
        street: street,
        rooms: rooms,
        area: area,
        land_area: land_area,
        floors: floors,
        house_type: house_type,
        deal_type: @deal_type,
        price: price,
        price_per_m2: price_per_m2 || (price && area && area > 0 ? (price / area).round(2) : nil),
        title: title,
        thumbnail_url: thumbnail_url,
        original_url: original_url
      }
    end

    def save_ads(ads)
      saved_count = 0

      ads.each do |ad_data|
        # Try to find by external_id first
        ad = SsHouseAd.find_by(external_id: ad_data[:external_id])

        # If not found, try to match by content hash (for re-posted ads)
        if ad.nil?
          content_hash = generate_content_hash([
            ad_data[:ss_region_id],
            ad_data[:ss_city_id],
            ad_data[:street]&.downcase&.strip,
            ad_data[:rooms],
            ad_data[:area]&.round(1),
            ad_data[:land_area]&.round(1),
            ad_data[:floors],
            ad_data[:house_type]
          ])

          # Look for matching hash from last 30 days
          ad = SsHouseAd.where(content_hash: content_hash)
                        .where("created_at > ?", 30.days.ago)
                        .first
        end

        if ad
          # Update existing ad
          ad.update!(
            external_id: ad_data[:external_id],
            ss_region_id: ad_data[:ss_region_id],
            ss_city_id: ad_data[:ss_city_id],
            street: ad_data[:street],
            rooms: ad_data[:rooms],
            area: ad_data[:area],
            land_area: ad_data[:land_area],
            floors: ad_data[:floors],
            house_type: ad_data[:house_type],
            deal_type: ad_data[:deal_type],
            price: ad_data[:price],
            price_per_m2: ad_data[:price_per_m2],
            title: ad_data[:title],
            thumbnail_url: ad_data[:thumbnail_url],
            original_url: ad_data[:original_url],
            last_seen_at: Time.current,
            active: true
          )

          # Record price if changed
          ad.record_price_if_changed(ad_data[:price], ad_data[:price_per_m2])
        else
          # Create new ad
          ad = SsHouseAd.create!(
            external_id: ad_data[:external_id],
            ss_region_id: ad_data[:ss_region_id],
            ss_city_id: ad_data[:ss_city_id],
            street: ad_data[:street],
            rooms: ad_data[:rooms],
            area: ad_data[:area],
            land_area: ad_data[:land_area],
            floors: ad_data[:floors],
            house_type: ad_data[:house_type],
            deal_type: ad_data[:deal_type],
            price: ad_data[:price],
            price_per_m2: ad_data[:price_per_m2],
            title: ad_data[:title],
            thumbnail_url: ad_data[:thumbnail_url],
            original_url: ad_data[:original_url],
            posted_at: Time.current,
            last_seen_at: Time.current,
            active: true
          )

          # Record initial price
          ad.record_price_if_changed(ad_data[:price], ad_data[:price_per_m2])
        end

        saved_count += 1
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.warn "[Sscom::HouseListingService] Failed to save ad #{ad_data[:external_id]}: #{e.message}"
      end

      saved_count
    end
  end
end
