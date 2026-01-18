require "net/http"
require "nokogiri"

module Sscom
  class BaseService
    BASE_URL = "https://www.ss.com".freeze

    # SS.COM uses different encodings for different languages:
    # - Latvian (/lv/): windows-1257 (Baltic)
    # - Russian (/ru/): windows-1251 (Cyrillic)
    ENCODING_BY_LANG = {
      "lv" => "windows-1257",
      "ru" => "windows-1251"
    }.freeze

    class SscomError < StandardError; end

    protected

    def fetch_page(path, encoding: nil)
      url = path.start_with?("http") ? path : "#{BASE_URL}#{path}"
      uri = URI(url)

      # Detect encoding from path language if not specified
      encoding ||= detect_encoding_from_path(path)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 15
      http.read_timeout = 30

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
      request["Accept"] = "text/html,application/xhtml+xml"
      request["Accept-Language"] = "lv,ru;q=0.9,en;q=0.8"

      response = http.request(request)

      if response.code == "200"
        # Try to detect encoding from response headers or HTML meta tag
        detected_encoding = detect_encoding_from_response(response) || encoding
        convert_encoding(response.body, detected_encoding)
      else
        Rails.logger.error "[Sscom::BaseService] HTTP #{response.code}: #{response.body[0..500]}"
        nil
      end
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      Rails.logger.error "[Sscom::BaseService] Timeout: #{e.message}"
      nil
    rescue StandardError => e
      Rails.logger.error "[Sscom::BaseService] Error fetching #{url}: #{e.message}"
      nil
    end

    def parse_html(html)
      return nil unless html
      Nokogiri::HTML(html)
    end

    def clean_text(text)
      return nil unless text
      text.to_s.strip.gsub(/\s+/, " ")
    end

    def extract_number(text)
      return nil unless text
      match = text.to_s.gsub(/\s/, "").match(/[\d,]+(?:\.\d+)?/)
      return nil unless match
      match[0].gsub(",", "").to_f
    end

    def extract_integer(text)
      num = extract_number(text)
      num&.to_i
    end

    def generate_content_hash(attributes)
      hash_content = attributes.map { |v| v.to_s.downcase.strip }.join("|")
      Digest::SHA256.hexdigest(hash_content)
    end

    private

    def detect_encoding_from_path(path)
      # Extract language from path like /lv/... or /ru/...
      lang_match = path.match(%r{^/([a-z]{2})/})
      lang = lang_match ? lang_match[1] : "lv"
      ENCODING_BY_LANG[lang] || "windows-1257"
    end

    def detect_encoding_from_response(response)
      # Try Content-Type header first
      content_type = response["Content-Type"]
      if content_type
        charset_match = content_type.match(/charset=([^\s;]+)/i)
        return normalize_encoding(charset_match[1]) if charset_match
      end

      # Try to find meta charset in the first 1024 bytes of body
      head = response.body[0..1024]
      if head
        # Look for <meta charset="..."> or <meta http-equiv="Content-Type" content="...charset=...">
        meta_match = head.match(/charset=["']?([^"'\s;>]+)/i)
        return normalize_encoding(meta_match[1]) if meta_match
      end

      nil
    end

    def normalize_encoding(encoding)
      # Normalize common encoding names
      case encoding.downcase.gsub("-", "")
      when "utf8"
        "UTF-8"
      when "windows1257", "cp1257"
        "windows-1257"
      when "windows1251", "cp1251"
        "windows-1251"
      when "iso88594", "latin4"
        "ISO-8859-4"
      when "iso885913"
        "ISO-8859-13"
      else
        encoding
      end
    end

    def convert_encoding(body, source_encoding)
      # Handle UTF-8 content (no conversion needed)
      if source_encoding.upcase == "UTF-8"
        body.force_encoding("UTF-8")
        return body
      end

      # Convert from source encoding to UTF-8
      body.force_encoding(source_encoding)
          .encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
    rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError => e
      Rails.logger.warn "[Sscom::BaseService] Encoding conversion issue from #{source_encoding}: #{e.message}"
      # Fallback: try common Baltic encodings
      try_fallback_encodings(body)
    end

    def try_fallback_encodings(body)
      # Try common encodings for Baltic/Latvian content
      %w[windows-1257 ISO-8859-13 ISO-8859-4 windows-1251 UTF-8].each do |enc|
        begin
          result = body.dup.force_encoding(enc).encode("UTF-8", invalid: :replace, undef: :replace)
          # Check if result looks valid (contains Latvian characters or no high-byte chars)
          if result.match?(/[āēīūļņķģšžčĀĒĪŪĻŅĶĢŠŽČ]/) || result.valid_encoding?
            Rails.logger.info "[Sscom::BaseService] Successfully converted using fallback encoding: #{enc}"
            return result
          end
        rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
          next
        end
      end

      # Last resort: force UTF-8
      body.force_encoding("UTF-8")
    end
  end
end
