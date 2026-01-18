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
        Rails.logger.warn "[Sscom::PriceCheckService] Failed to fetch ad page"
        return { success: false, error: "Failed to fetch ad page", ad_removed: check_if_removed(@ad.original_url) }
      end

      doc = parse_html(html)
      return { success: false, error: "Failed to parse HTML" } unless doc

      # Check if ad is still active
      if ad_removed?(doc)
        Rails.logger.info "[Sscom::PriceCheckService] Ad #{@ad.external_id} appears to be removed"
        @ad.update!(active: false, last_seen_at: Time.current)
        return { success: true, ad_removed: true }
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
      # Check for common indicators that ad has been removed
      page_text = doc.text.downcase

      page_text.include?("sludinājums ir dzēsts") ||
        page_text.include?("объявление удалено") ||
        page_text.include?("ad has been deleted") ||
        page_text.include?("nav atrasts") ||
        page_text.include?("не найдено") ||
        doc.at_css(".msg_div_msg, .msga2-o, .msg-body").nil?
    end

    def check_if_removed(url)
      # Quick check if URL returns 404 or shows removed message
      html = fetch_page(url)
      return true unless html

      doc = parse_html(html)
      return true unless doc

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
