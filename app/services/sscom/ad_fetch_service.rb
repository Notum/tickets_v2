module Sscom
  class AdFetchService < BaseService
    # Fetches an ad from a direct SS.COM URL and creates/updates the ad record
    # Supports both flats and houses
    #
    # URL patterns:
    # Flats:  /msg/{lang}/real-estate/flats/{region}/{city}/{external_id}.html
    # Houses: /msg/{lang}/real-estate/homes-summer-residences/{region}/{city}/.../{external_id}.html

    class InvalidUrlError < SscomError; end
    class AdNotFoundError < SscomError; end

    FLAT_PATTERN = %r{ss\.com/msg/[a-z]{2}/real-estate/flats/}i.freeze
    HOUSE_PATTERN = %r{ss\.com/msg/[a-z]{2}/real-estate/homes-summer-residences/}i.freeze

    def initialize(url:)
      @url = url.strip
    end

    def call
      Rails.logger.info "[Sscom::AdFetchService] Fetching ad from URL: #{@url}"

      validate_url!
      determine_ad_type!

      # Check if ad already exists
      existing_ad = find_existing_ad
      if existing_ad
        Rails.logger.info "[Sscom::AdFetchService] Found existing ad: #{existing_ad.id}"
        return { success: true, ad: existing_ad, ad_type: @ad_type, existing: true }
      end

      # Fetch the page
      html = fetch_page(@url)
      unless html
        return { success: false, error: "Could not fetch ad page. The ad may have been removed." }
      end

      doc = parse_html(html)
      unless doc
        return { success: false, error: "Could not parse ad page" }
      end

      # Check if ad is removed
      if ad_removed?(doc)
        return { success: false, error: "This ad has been removed from SS.COM" }
      end

      # Parse ad details
      ad_data = parse_ad_details(doc)
      unless ad_data[:price]
        return { success: false, error: "Could not extract price from ad" }
      end

      # Find or create region and city
      region_city = resolve_region_and_city(doc)
      unless region_city[:region]
        return { success: false, error: "Could not determine region for this ad" }
      end

      # Create the ad
      ad = create_ad(ad_data, region_city)
      if ad.persisted?
        ad.record_price_if_changed(ad.price, ad.price_per_m2)
        Rails.logger.info "[Sscom::AdFetchService] Created new ad: #{ad.id}"
        { success: true, ad: ad, ad_type: @ad_type, existing: false }
      else
        { success: false, error: ad.errors.full_messages.join(", ") }
      end
    rescue InvalidUrlError => e
      { success: false, error: e.message }
    rescue StandardError => e
      Rails.logger.error "[Sscom::AdFetchService] Error: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      { success: false, error: "An error occurred while fetching the ad: #{e.message}" }
    end

    private

    def validate_url!
      unless @url.match?(%r{^https?://.*ss\.com/msg/})
        raise InvalidUrlError, "Invalid SS.COM URL. Please provide a direct link to an ad (e.g., https://www.ss.com/msg/...)"
      end
    end

    def determine_ad_type!
      if @url.match?(FLAT_PATTERN)
        @ad_type = :flat
      elsif @url.match?(HOUSE_PATTERN)
        @ad_type = :house
      else
        raise InvalidUrlError, "URL must be for a flat or house listing from SS.COM"
      end
    end

    def extract_external_id
      # External ID is the filename without .html extension
      # e.g., ocfek.html -> ocfek
      match = @url.match(%r{/([a-z0-9]+)\.html}i)
      match ? match[1] : nil
    end

    def find_existing_ad
      external_id = extract_external_id
      return nil unless external_id

      if @ad_type == :flat
        SsFlatAd.find_by(external_id: external_id)
      else
        SsHouseAd.find_by(external_id: external_id)
      end
    end

    def ad_removed?(doc)
      page_text = doc.text.downcase

      page_text.include?("sludinājums ir dzēsts") ||
        page_text.include?("объявление удалено") ||
        page_text.include?("ad has been deleted") ||
        page_text.include?("nav atrasts") ||
        page_text.include?("не найдено") ||
        doc.at_css("#msg_div_msg, #content_main_div, .options_list").nil?
    end

    def parse_ad_details(doc)
      data = {
        external_id: extract_external_id,
        original_url: @url,
        title: extract_title(doc),
        price: nil,
        price_per_m2: nil,
        rooms: nil,
        area: nil,
        street: nil,
        deal_type: extract_deal_type,
        thumbnail_url: extract_thumbnail(doc),
        image_urls: extract_images(doc),
        posted_at: Time.current,
        last_seen_at: Time.current,
        active: true
      }

      # Parse the table with ad details
      doc.css("table.options_list tr, table#content_main_table tr").each do |row|
        cells = row.css("td")
        next unless cells.length >= 2

        label = clean_text(cells[0].text)&.downcase
        value = clean_text(cells[1].text)

        case label
        when /cena|price|цена/
          data[:price] = extract_number(value)
        when /m²|кв\.м/
          data[:price_per_m2] = extract_number(value)
        when /istab|room|комнат/
          data[:rooms] = extract_integer(value)
        when /platība|area|площадь/
          data[:area] = extract_number(value)
        when /stāv|floor|этаж/
          if @ad_type == :flat
            floors = value.match(/(\d+)\s*\/\s*(\d+)/)
            if floors
              data[:floor_current] = floors[1].to_i
              data[:floor_total] = floors[2].to_i
            else
              data[:floor_current] = extract_integer(value)
            end
          else
            data[:floors] = extract_integer(value)
          end
        when /sērija|series|серия/
          data[:building_series] = extract_building_series(value)
        when /zeme|land|земл/
          data[:land_area] = extract_number(value)
        when /adrese|address|адрес|iela|street|улица/
          data[:street] = value
        when /tips|type|тип/
          data[:house_type] = value
        end
      end

      # Try alternative price extraction if not found
      unless data[:price]
        price_el = doc.at_css(".ads_price, .ads_opt_price, td.msg2 b")
        if price_el
          price_text = clean_text(price_el.text)
          data[:price] = extract_number(price_text) if price_text
        end
      end

      # Alternative: Look for price in any element with € symbol
      unless data[:price]
        doc.css("td, span, div, b").each do |el|
          text = clean_text(el.text)
          next unless text

          if text.match?(/(\d[\d\s,]*)\s*€/) && !text.match?(/€\s*\/\s*m/)
            price = extract_number(text)
            if price && price > 100
              data[:price] = price
              break
            end
          end
        end
      end

      data
    end

    def extract_title(doc)
      title_el = doc.at_css("td.msg_title, h1.msg_h1, .ads_title")
      clean_text(title_el&.text)
    end

    def extract_deal_type
      # Try to determine deal type from URL
      if @url.include?("/sell/") || @url.include?("/hand_over/")
        "sell"
      elsif @url.include?("/rent/")
        "rent_out"
      elsif @url.include?("/buy/")
        "buy"
      elsif @url.include?("/rent_want/")
        "rent_want"
      elsif @url.include?("/exchange/")
        "exchange"
      else
        # Default to sell - most common
        "sell"
      end
    end

    def extract_thumbnail(doc)
      img = doc.at_css(".msg_img img, .pic_dv_thumbnail img, .ads_photo img")
      img&.attr("src")
    end

    def extract_images(doc)
      images = []
      doc.css(".pic_dv_thumbnail img, .ads_photo img, .msg_img img").each do |img|
        src = img.attr("src")
        images << src if src.present?
      end
      images.uniq
    end

    def extract_building_series(text)
      return nil unless text
      series = SsFlatAd::BUILDING_SERIES.find { |s| text.downcase.include?(s.downcase) }
      series || text.strip
    end

    def resolve_region_and_city(doc)
      # Try to extract from breadcrumbs or page structure
      region = nil
      city = nil

      # Extract from URL path
      url_parts = extract_url_parts

      # Try to find region by slug from URL
      if url_parts[:region_slug]
        region = SsRegion.find_by("slug LIKE ?", "%#{url_parts[:region_slug]}%")
      end

      # Try to find city by slug from URL
      if url_parts[:city_slug] && region
        city = region.ss_cities.find_by("slug LIKE ?", "%#{url_parts[:city_slug]}%")
      end

      # Fallback: Try breadcrumbs
      unless region
        doc.css("a").each do |link|
          href = link.attr("href")
          next unless href

          if @ad_type == :flat && href.match?(%r{/real-estate/flats/([^/]+)/?$})
            slug = $1
            region ||= SsRegion.find_by(slug: slug)
          elsif @ad_type == :house && href.match?(%r{/real-estate/homes-summer-residences/([^/]+)/?$})
            slug = $1
            region ||= SsRegion.find_by(slug: slug)
          end
        end
      end

      # Last resort: Create unknown region or use Riga
      unless region
        region = SsRegion.find_by(slug: "riga") || SsRegion.first
      end

      { region: region, city: city }
    end

    def extract_url_parts
      parts = {}

      if @ad_type == :flat
        # Pattern: /msg/ru/real-estate/flats/{region}/{city}/{id}.html
        match = @url.match(%r{/real-estate/flats/([^/]+)/([^/]+)/})
        if match
          parts[:region_slug] = match[1]
          parts[:city_slug] = match[2]
        end
      else
        # Pattern: /msg/ru/real-estate/homes-summer-residences/{region}/{city}/.../{id}.html
        match = @url.match(%r{/real-estate/homes-summer-residences/([^/]+)/([^/]+)/})
        if match
          parts[:region_slug] = match[1]
          parts[:city_slug] = match[2]
        end
      end

      parts
    end

    def create_ad(ad_data, region_city)
      if @ad_type == :flat
        SsFlatAd.create(
          external_id: ad_data[:external_id],
          content_hash: generate_content_hash_for_ad(ad_data, region_city),
          original_url: ad_data[:original_url],
          title: ad_data[:title],
          price: ad_data[:price],
          price_per_m2: ad_data[:price_per_m2],
          rooms: ad_data[:rooms],
          area: ad_data[:area],
          floor_current: ad_data[:floor_current],
          floor_total: ad_data[:floor_total],
          building_series: ad_data[:building_series],
          street: ad_data[:street],
          deal_type: ad_data[:deal_type],
          thumbnail_url: ad_data[:thumbnail_url],
          image_urls: ad_data[:image_urls],
          posted_at: ad_data[:posted_at],
          last_seen_at: ad_data[:last_seen_at],
          active: ad_data[:active],
          ss_region: region_city[:region],
          ss_city: region_city[:city]
        )
      else
        SsHouseAd.create(
          external_id: ad_data[:external_id],
          content_hash: generate_content_hash_for_ad(ad_data, region_city),
          original_url: ad_data[:original_url],
          title: ad_data[:title],
          price: ad_data[:price],
          price_per_m2: ad_data[:price_per_m2],
          rooms: ad_data[:rooms],
          area: ad_data[:area],
          land_area: ad_data[:land_area],
          floors: ad_data[:floors],
          house_type: ad_data[:house_type],
          street: ad_data[:street],
          deal_type: ad_data[:deal_type],
          thumbnail_url: ad_data[:thumbnail_url],
          image_urls: ad_data[:image_urls],
          posted_at: ad_data[:posted_at],
          last_seen_at: ad_data[:last_seen_at],
          active: ad_data[:active],
          ss_region: region_city[:region],
          ss_city: region_city[:city]
        )
      end
    end

    def generate_content_hash_for_ad(ad_data, region_city)
      if @ad_type == :flat
        hash_content = [
          region_city[:region]&.id,
          region_city[:city]&.id,
          ad_data[:street]&.downcase&.strip,
          ad_data[:rooms],
          ad_data[:area]&.round(1),
          ad_data[:floor_current],
          ad_data[:floor_total],
          ad_data[:building_series]
        ].join("|")
      else
        hash_content = [
          region_city[:region]&.id,
          region_city[:city]&.id,
          ad_data[:street]&.downcase&.strip,
          ad_data[:rooms],
          ad_data[:area]&.round(1),
          ad_data[:land_area]&.round(1),
          ad_data[:floors],
          ad_data[:house_type]
        ].join("|")
      end
      Digest::SHA256.hexdigest(hash_content)
    end
  end
end
