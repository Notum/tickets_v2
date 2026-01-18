module Sscom
  class RegionsSyncService < BaseService
    # SS.COM real estate section URLs
    FLATS_URL = "/lv/real-estate/flats/".freeze
    HOUSES_URL = "/lv/real-estate/homes-summer-residences/".freeze

    # Non-geographic slugs to exclude (navigation links, not real regions)
    EXCLUDED_SLUGS = %w[new search other rss flats-abroad-latvia today filter].freeze

    def call
      Rails.logger.info "[Sscom::RegionsSyncService] Starting regions sync"

      # Fetch the flats page to get region hierarchy
      html = fetch_page(FLATS_URL)
      return { success: false, error: "Failed to fetch regions page" } unless html

      doc = parse_html(html)
      return { success: false, error: "Failed to parse HTML" } unless doc

      regions = parse_regions(doc)
      Rails.logger.info "[Sscom::RegionsSyncService] Found #{regions.count} regions"

      created_regions = 0
      updated_regions = 0
      created_cities = 0
      updated_cities = 0

      regions.each_with_index do |region_data, position|
        region = SsRegion.find_or_initialize_by(slug: region_data[:slug])
        is_new = region.new_record?

        region.assign_attributes(
          name_lv: region_data[:name_lv],
          name_ru: region_data[:name_ru],
          parent_slug: region_data[:parent_slug],
          position: position,
          last_synced_at: Time.current
        )
        region.save!

        if is_new
          created_regions += 1
        else
          updated_regions += 1
        end

        # Sync cities for this region
        region_data[:cities]&.each_with_index do |city_data, city_position|
          city = SsCity.find_or_initialize_by(ss_region: region, slug: city_data[:slug])
          city_is_new = city.new_record?

          city.assign_attributes(
            name_lv: city_data[:name_lv],
            name_ru: city_data[:name_ru],
            position: city_position
          )
          city.save!

          if city_is_new
            created_cities += 1
          else
            updated_cities += 1
          end
        end
      end

      result = {
        success: true,
        created_regions: created_regions,
        updated_regions: updated_regions,
        created_cities: created_cities,
        updated_cities: updated_cities
      }

      Rails.logger.info "[Sscom::RegionsSyncService] Sync complete: #{result}"
      result
    rescue StandardError => e
      Rails.logger.error "[Sscom::RegionsSyncService] Error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      { success: false, error: e.message }
    end

    private

    def parse_regions(doc)
      regions = []

      # SS.COM has a region selector with links like /lv/real-estate/flats/riga/
      # Look for region links in the navigation/filter area
      doc.css('a[href*="/real-estate/flats/"]').each do |link|
        href = link["href"].to_s
        text = clean_text(link.text)

        # Skip the main category link and filter out non-region links
        next if href == FLATS_URL || href.end_with?("/flats/")
        next if text.blank? || text.length < 2

        # Extract region slug from URL like /lv/real-estate/flats/riga/
        slug_match = href.match(%r{/real-estate/flats/([^/]+)/?$})
        next unless slug_match

        slug = slug_match[1]

        # Skip navigation/non-geographic slugs
        next if EXCLUDED_SLUGS.include?(slug)

        # Skip if already added
        next if regions.any? { |r| r[:slug] == slug }

        regions << {
          slug: slug,
          name_lv: text,
          name_ru: nil, # Will be fetched from Russian version if needed
          parent_slug: nil,
          cities: fetch_cities_for_region(slug)
        }
      end

      # If no regions found from links, use hardcoded list of major regions
      if regions.empty?
        regions = default_regions
      end

      regions
    end

    def fetch_cities_for_region(region_slug)
      # Fetch the region page to get cities
      html = fetch_page("/lv/real-estate/flats/#{region_slug}/")
      return [] unless html

      doc = parse_html(html)
      return [] unless doc

      cities = []

      # Look for city/district links within the region
      doc.css('a[href*="/real-estate/flats/"]').each do |link|
        href = link["href"].to_s
        text = clean_text(link.text)

        # Match URLs like /lv/real-estate/flats/riga/centre/
        city_match = href.match(%r{/real-estate/flats/#{Regexp.escape(region_slug)}/([^/]+)/?$})
        next unless city_match

        city_slug = city_match[1]
        next if city_slug.blank? || text.blank?
        next if EXCLUDED_SLUGS.include?(city_slug)
        next if cities.any? { |c| c[:slug] == city_slug }

        cities << {
          slug: city_slug,
          name_lv: text,
          name_ru: nil
        }
      end

      cities
    end

    def default_regions
      # Fallback list of major Latvian regions on SS.COM
      [
        { slug: "riga", name_lv: "Rīga", name_ru: "Рига", parent_slug: nil, cities: [] },
        { slug: "riga-region", name_lv: "Rīgas rajons", name_ru: "Рижский район", parent_slug: nil, cities: [] },
        { slug: "jurmala", name_lv: "Jūrmala", name_ru: "Юрмала", parent_slug: nil, cities: [] },
        { slug: "daugavpils-and-reg", name_lv: "Daugavpils un raj.", name_ru: "Даугавпилс и район", parent_slug: nil, cities: [] },
        { slug: "jelgava-and-reg", name_lv: "Jelgava un raj.", name_ru: "Елгава и район", parent_slug: nil, cities: [] },
        { slug: "liepaja-and-reg", name_lv: "Liepāja un raj.", name_ru: "Лиепая и район", parent_slug: nil, cities: [] },
        { slug: "ventspils-and-reg", name_lv: "Ventspils un raj.", name_ru: "Вентспилс и район", parent_slug: nil, cities: [] },
        { slug: "valmiera-and-reg", name_lv: "Valmiera un raj.", name_ru: "Валмиера и район", parent_slug: nil, cities: [] },
        { slug: "cesis-and-reg", name_lv: "Cēsis un raj.", name_ru: "Цесис и район", parent_slug: nil, cities: [] },
        { slug: "rezekne-and-reg", name_lv: "Rēzekne un raj.", name_ru: "Резекне и район", parent_slug: nil, cities: [] },
        { slug: "ogre-and-reg", name_lv: "Ogre un raj.", name_ru: "Огре и район", parent_slug: nil, cities: [] },
        { slug: "tukums-and-reg", name_lv: "Tukums un raj.", name_ru: "Тукумс и район", parent_slug: nil, cities: [] },
        { slug: "sigulda-and-reg", name_lv: "Sigulda un raj.", name_ru: "Сигулда и район", parent_slug: nil, cities: [] },
        { slug: "saulkrasti-and-reg", name_lv: "Saulkrasti un raj.", name_ru: "Саулкрасты и район", parent_slug: nil, cities: [] }
      ]
    end
  end
end
