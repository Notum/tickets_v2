module Sscom
  class PriceCheckService < BaseService
    # Checks current price for a followed ad by fetching its page

    def initialize(ad:)
      @ad = ad
    end

    def call
      Rails.logger.info "[Sscom::PriceCheckService] Checking price for ad #{@ad.external_id}"

      html = fetch_page(@ad.original_url)
      unless html
        Rails.logger.warn "[Sscom::PriceCheckService] Failed to fetch ad page - network error or timeout"
        # Don't mark as removed on fetch failure - could be temporary network issue
        return { success: false, error: "Failed to fetch ad page" }
      end

      doc = parse_html(html)
      return { success: false, error: "Failed to parse HTML" } unless doc

      # Check if ad is explicitly marked as removed (with specific removal messages)
      if ad_removed?(doc)
        Rails.logger.info "[Sscom::PriceCheckService] Ad #{@ad.external_id} confirmed as removed (removal message found)"
        @ad.update!(active: false, last_seen_at: Time.current)
        return { success: true, ad_removed: true }
      end

      # Check if page looks like a valid ad page
      unless page_looks_valid?(doc)
        Rails.logger.warn "[Sscom::PriceCheckService] Page doesn't look like a valid ad (missing expected elements)"
        # Don't mark as removed - could be HTML structure change or error page
        return { success: false, error: "Page structure not recognized - please verify ad manually" }
      end

      # Extract current price
      price_data = extract_price(doc)
      unless price_data[:price]
        Rails.logger.warn "[Sscom::PriceCheckService] Could not extract price from page"
        return { success: false, error: "Could not extract price" }
      end

      previous_price = @ad.price
      price_changed = previous_price != price_data[:price]

      # Update ad with new price
      @ad.update!(
        price: price_data[:price],
        price_per_m2: price_data[:price_per_m2],
        last_seen_at: Time.current
      )

      # Record price history if changed
      @ad.record_price_if_changed(price_data[:price], price_data[:price_per_m2])

      result = {
        success: true,
        price: price_data[:price],
        price_per_m2: price_data[:price_per_m2],
        previous_price: previous_price,
        price_changed: price_changed
      }

      # Add price drop info if applicable
      if price_changed && previous_price && price_data[:price] < previous_price
        result[:price_drop] = {
          savings: previous_price - price_data[:price],
          previous_price: previous_price,
          current_price: price_data[:price],
          percentage: ((previous_price - price_data[:price]) / previous_price * 100).round(1)
        }
      end

      Rails.logger.info "[Sscom::PriceCheckService] Price check complete: #{result}"
      result
    rescue StandardError => e
      Rails.logger.error "[Sscom::PriceCheckService] Error: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      { success: false, error: e.message }
    end

    private

    def ad_removed?(doc)
      # Check for POSITIVE indicators that ad has been removed
      # We should only mark as removed if we find explicit removal messages,
      # NOT if elements are simply missing (could be HTML structure change, etc.)
      page_text = doc.text.downcase

      removal_confirmed = page_text.include?("sludinājums ir dzēsts") ||
        page_text.include?("объявление удалено") ||
        page_text.include?("ad has been deleted") ||
        page_text.include?("nav atrasts") ||
        page_text.include?("не найдено") ||
        page_text.include?("sludinājums nav atrasts") ||
        page_text.include?("объявление не найдено")

      if removal_confirmed
        Rails.logger.info "[Sscom::PriceCheckService] Removal message found in page"
      end

      removal_confirmed
    end

    def page_looks_valid?(doc)
      # Check if the page looks like a valid ad page (has expected structure)
      doc.at_css(".msg_div_msg, .msga2-o, .msg-body, #msg_div_msg, .options_list, #content_main_div").present?
    end

    def check_if_removed(url)
      # Quick check if URL returns 404 or shows removed message
      # Returns nil if we can't determine (fetch failed), true if confirmed removed, false if still active
      html = fetch_page(url)
      return nil unless html  # Can't determine - don't mark as removed

      doc = parse_html(html)
      return nil unless doc  # Can't determine - don't mark as removed

      ad_removed?(doc)
    end

    def extract_price(doc)
      price = nil
      price_per_m2 = nil

      # Look for price in the ad details section
      # SS.COM typically shows price in a prominent location

      # Try main price element
      price_element = doc.at_css(".ads_price, .price, td.msg2 b, .msg_div_price")
      if price_element
        price_text = clean_text(price_element.text)
        price = extract_number(price_text)
      end

      # Try alternative price patterns
      unless price
        doc.css("td, span, div").each do |element|
          text = clean_text(element.text)
          next unless text

          # Look for price with euro symbol
          if text.match?(/(\d[\d\s,]*)\s*€/) && !text.match?(/€\/m/)
            price = extract_number(text)
            break if price && price > 100
          end
        end
      end

      # Look for price per m2
      doc.css("td, span, div").each do |element|
        text = clean_text(element.text)
        next unless text

        if text.match?(/(\d[\d\s,]*)\s*€\s*\/\s*m/)
          price_per_m2 = extract_number(text)
          break if price_per_m2
        end
      end

      # Calculate price_per_m2 if not found and we have area
      if price && !price_per_m2 && @ad.area && @ad.area > 0
        price_per_m2 = (price / @ad.area).round(2)
      end

      { price: price, price_per_m2: price_per_m2 }
    end
  end
end
