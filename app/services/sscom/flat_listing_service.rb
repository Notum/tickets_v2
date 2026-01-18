module Sscom
  class FlatListingService < BaseService
    # Deal type URL segments on SS.COM
    DEAL_TYPES = {
      "sell" => "sell",
      "buy" => "buy",
      "rent_out" => "hand_over",
      "rent_want" => "wanted",
      "exchange" => "exchange"
    }.freeze

    MAX_PAGES = 20 # Safety limit to avoid infinite loops

    def initialize(region: nil, city: nil, deal_type: "sell", filters: {})
      @region = region
      @city = city
      @deal_type = deal_type
      @filters = filters
    end

    def call
      Rails.logger.info "[Sscom::FlatListingService] Fetching flats for region=#{@region&.slug}, city=#{@city&.slug}, deal_type=#{@deal_type}"

      unless @region
        return { success: false, error: "Region is required" }
      end

      all_ads = []
      base_url = build_listing_url

      # Fetch first page
      Rails.logger.info "[Sscom::FlatListingService] Fetching page 1: #{base_url}"
      html = fetch_page(base_url)
      return { success: false, error: "Failed to fetch listings page" } unless html

      doc = parse_html(html)
      return { success: false, error: "Failed to parse HTML" } unless doc

      ads = parse_listings(doc)
      all_ads.concat(ads)
      Rails.logger.info "[Sscom::FlatListingService] Page 1: found #{ads.count} ads"

      # Check for pagination and fetch remaining pages
      total_pages = detect_total_pages(doc)
      Rails.logger.info "[Sscom::FlatListingService] Total pages detected: #{total_pages}"

      if total_pages > 1
        (2..total_pages).each do |page_num|
          page_url = build_page_url(base_url, page_num)
          Rails.logger.info "[Sscom::FlatListingService] Fetching page #{page_num}: #{page_url}"

          html = fetch_page(page_url)
          next unless html

          doc = parse_html(html)
          next unless doc

          page_ads = parse_listings(doc)
          all_ads.concat(page_ads)
          Rails.logger.info "[Sscom::FlatListingService] Page #{page_num}: found #{page_ads.count} ads"

          # Small delay to be nice to the server
          sleep(0.5)
        end
      end

      Rails.logger.info "[Sscom::FlatListingService] Total ads found across all pages: #{all_ads.count}"

      saved_count = save_ads(all_ads)

      {
        success: true,
        total: all_ads.count,
        saved: saved_count,
        pages: total_pages,
        ads: all_ads
      }
    rescue StandardError => e
      Rails.logger.error "[Sscom::FlatListingService] Error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      { success: false, error: e.message }
    end

    private

    def detect_total_pages(doc)
      # SS.COM pagination uses links with class "navi"
      # Example: <a class="navi" href="page2.html">2</a>
      page_links = doc.css('a.navi')

      max_page = 1
      page_links.each do |link|
        text = link.text.strip
        # Only consider numeric page links (not "Предыдущие"/"Следующие" text links)
        if text.match?(/^\d+$/)
          page_num = text.to_i
          max_page = page_num if page_num > max_page
        end
      end

      # Apply safety limit
      [max_page, MAX_PAGES].min
    end

    def build_page_url(base_url, page_num)
      # SS.COM pagination format: /path/to/listings/page2.html
      # Base URL ends with "/" or "/?params"

      if base_url.include?("?")
        # Has query params: /path/sell/?param=value -> /path/sell/page2.html?param=value
        path, params = base_url.split("?", 2)
        path = path.chomp("/")
        "#{path}/page#{page_num}.html?#{params}"
      else
        # No query params: /path/sell/ -> /path/sell/page2.html
        path = base_url.chomp("/")
        "#{path}/page#{page_num}.html"
      end
    end

    def build_listing_url
      base = "/lv/real-estate/flats"
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

      # Area filter (m2)
      if @filters[:area_min] || @filters[:area_max]
        params["topt[3][min]"] = @filters[:area_min] if @filters[:area_min]
        params["topt[3][max]"] = @filters[:area_max] if @filters[:area_max]
      end

      # Floor filter
      if @filters[:floor_min] || @filters[:floor_max]
        params["topt[4][min]"] = @filters[:floor_min] if @filters[:floor_min]
        params["topt[4][max]"] = @filters[:floor_max] if @filters[:floor_max]
      end

      # Price filter
      if @filters[:price_min] || @filters[:price_max]
        params["topt[8][min]"] = @filters[:price_min] if @filters[:price_min]
        params["topt[8][max]"] = @filters[:price_max] if @filters[:price_max]
      end

      # Building series filter
      if @filters[:building_series]
        params["topt[6]"] = @filters[:building_series]
      end

      params
    end

    def parse_listings(doc)
      ads = []

      # SS.COM listings are in table rows with class "msg2" or in a specific table structure
      # Each ad row typically has: photo, description, rooms, area, floor, price, etc.
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

      # Parse table cells for data (SS.COM uses specific column positions)
      cells = row.css("td")

      # The structure varies but typically:
      # - Description/title is in a link
      # - Other columns: street, rooms, m2, floor, building_series, price, price/m2
      title = clean_text(link.text)

      # Try to extract data from cells
      rooms = nil
      area = nil
      floor_current = nil
      floor_total = nil
      street = nil
      building_series = nil
      price = nil
      price_per_m2 = nil

      cells.each_with_index do |cell, idx|
        text = clean_text(cell.text)
        next if text.blank?

        # Check for room count (single digit or "1-ist.", "2-ist." etc.)
        if text.match?(/^\d$/) && rooms.nil?
          rooms = text.to_i
        # Check for area (contains m2 or just a decimal number)
        elsif text.match?(/^\d+(?:[.,]\d+)?$/) && area.nil? && rooms.present?
          area = extract_number(text)
        # Check for floor (format: "5/9" or "5 / 9")
        elsif text.match?(%r{\d+\s*/\s*\d+})
          floor_match = text.match(%r{(\d+)\s*/\s*(\d+)})
          if floor_match
            floor_current = floor_match[1].to_i
            floor_total = floor_match[2].to_i
          end
        # Check for price (contains currency symbol or large number)
        elsif text.match?(/[\d\s,]+\s*€/) || (text.gsub(/\s/, "").match?(/^\d{4,}$/) && price.nil?)
          price = extract_number(text)
        # Check for price per m2
        elsif text.match?(/[\d\s,]+\s*€\/m/)
          price_per_m2 = extract_number(text)
        # Building series (common patterns: 103, 104, 119, 467, 602, Hrušč., etc.)
        elsif text.match?(/^(103|104|119|467|602|hrušč|Hrušč|staļ|Staļ|spec|Spec|jaun|Jaun|lit|Lit|renov|Renov)/i)
          building_series = text
        # Street name (longer text that's not one of the above)
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
        floor_current: floor_current,
        floor_total: floor_total,
        building_series: building_series,
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
        ad = SsFlatAd.find_by(external_id: ad_data[:external_id])

        # If not found, try to match by content hash (for re-posted ads)
        if ad.nil?
          content_hash = generate_content_hash([
            ad_data[:ss_region_id],
            ad_data[:ss_city_id],
            ad_data[:street]&.downcase&.strip,
            ad_data[:rooms],
            ad_data[:area]&.round(1),
            ad_data[:floor_current],
            ad_data[:floor_total],
            ad_data[:building_series]
          ])

          # Look for matching hash from last 30 days
          ad = SsFlatAd.where(content_hash: content_hash)
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
            floor_current: ad_data[:floor_current],
            floor_total: ad_data[:floor_total],
            building_series: ad_data[:building_series],
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
          ad = SsFlatAd.create!(
            external_id: ad_data[:external_id],
            ss_region_id: ad_data[:ss_region_id],
            ss_city_id: ad_data[:ss_city_id],
            street: ad_data[:street],
            rooms: ad_data[:rooms],
            area: ad_data[:area],
            floor_current: ad_data[:floor_current],
            floor_total: ad_data[:floor_total],
            building_series: ad_data[:building_series],
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
        Rails.logger.warn "[Sscom::FlatListingService] Failed to save ad #{ad_data[:external_id]}: #{e.message}"
      end

      saved_count
    end
  end
end
