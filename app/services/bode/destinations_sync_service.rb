require "net/http"
require "nokogiri"

module Bode
  class DestinationsSyncService
    BASE_URL = "https://bode.lv".freeze
    CHARTERS_URL = "#{BASE_URL}/ru/charteri".freeze

    def call
      Rails.logger.info "[Bode::DestinationsSyncService] Fetching destinations from #{CHARTERS_URL}"

      html = fetch_page(CHARTERS_URL)
      return { success: false, error: "Failed to fetch page" } unless html

      destinations = parse_destinations(html)
      Rails.logger.info "[Bode::DestinationsSyncService] Found #{destinations.count} Riga round-trip destinations"

      created = 0
      updated = 0
      synced_ids = []

      destinations.each do |dest|
        # Find by name first (to avoid duplicates by destination name)
        # Use active: true preference to get the canonical record
        record_by_name = BodeDestination.where(name: dest[:name]).order(active: :desc, id: :desc).first
        record_by_path = BodeDestination.find_by(charter_path: dest[:charter_path])

        if record_by_name
          # Destination with this name exists
          if record_by_path && record_by_path.id != record_by_name.id
            # Charter path exists on different record - merge flight searches and remove conflicting path
            record_by_path.bode_flight_searches.update_all(bode_destination_id: record_by_name.id)
            # Clear the charter_path before deactivating to avoid uniqueness conflict
            record_by_path.update_columns(charter_path: "#{record_by_path.charter_path}_archived_#{record_by_path.id}", active: false)
          end
          record_by_name.update!(dest.merge(last_synced_at: Time.current, active: true))
          synced_ids << record_by_name.id
          updated += 1
        elsif record_by_path
          # No name match but charter_path exists - update name
          record_by_path.update!(dest.merge(last_synced_at: Time.current, active: true))
          synced_ids << record_by_path.id
          updated += 1
        else
          # New destination
          record = BodeDestination.create!(dest.merge(active: true))
          synced_ids << record.id
          created += 1
        end
      end

      # Mark destinations not found in current sync as inactive
      deactivated = BodeDestination.where.not(id: synced_ids).where(active: true).update_all(active: false)
      Rails.logger.info "[Bode::DestinationsSyncService] Deactivated #{deactivated} destinations not found in Bode"

      Rails.logger.info "[Bode::DestinationsSyncService] Created: #{created}, Updated: #{updated}, Deactivated: #{deactivated}"
      { success: true, created: created, updated: updated, deactivated: deactivated, total: destinations.count }
    rescue StandardError => e
      Rails.logger.error "[Bode::DestinationsSyncService] Error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      { success: false, error: e.message }
    end

    private

    def fetch_page(url)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 15
      http.read_timeout = 30

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
      request["Accept"] = "text/html,application/xhtml+xml"
      request["Accept-Language"] = "ru,en;q=0.9"

      response = http.request(request)

      if response.code == "200"
        response.body
      else
        Rails.logger.error "[Bode::DestinationsSyncService] HTTP #{response.code}: #{response.body[0..500]}"
        nil
      end
    end

    def parse_destinations(html)
      doc = Nokogiri::HTML(html)
      destinations = []

      # Find all links that match the pattern ru/charteri/charter/XX or /ru/charteri/charter/XX
      doc.css('a[href*="charteri/charter/"]').each do |link|
        href = link["href"]
        text = link.text.strip

        # Only include Riga round trips (Рига - X - Рига)
        next unless text.match?(/^Рига\s*[-–—].*[-–—]\s*Рига$/i)

        # Normalize the path (ensure it starts with /)
        charter_path = href.start_with?("/") ? href : "/#{href}"

        # Skip if already added (avoid duplicates)
        next if destinations.any? { |d| d[:charter_path] == charter_path }

        destinations << {
          name: text,
          charter_path: charter_path,
          last_synced_at: Time.current
        }
      end

      destinations
    end
  end
end
