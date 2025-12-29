require "net/http"
require "json"

class FlaresolverrService
  FLARESOLVERR_URL = ENV.fetch("FLARESOLVERR_URL", "http://localhost:8191/v1")
  MAX_TIMEOUT = 60_000 # 60 seconds

  class FlaresolverrError < StandardError; end

  # Fetch a URL through FlareSolverr, bypassing Cloudflare protection
  # Returns parsed JSON if response is JSON, otherwise returns the raw HTML
  def fetch(url)
    Rails.logger.info "[FlaresolverrService] Fetching: #{url}"

    uri = URI(FLARESOLVERR_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 120 # FlareSolverr can take a while

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/json"
    request.body = {
      cmd: "request.get",
      url: url,
      maxTimeout: MAX_TIMEOUT
    }.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise FlaresolverrError, "FlareSolverr returned HTTP #{response.code}: #{response.body.first(200)}"
    end

    result = JSON.parse(response.body)

    if result["status"] != "ok"
      raise FlaresolverrError, "FlareSolverr error: #{result['message']}"
    end

    solution = result["solution"]
    page_content = solution["response"]

    Rails.logger.info "[FlaresolverrService] Got response (#{page_content.length} bytes), status: #{solution['status']}"

    # Try to parse as JSON (for API responses)
    begin
      JSON.parse(page_content)
    rescue JSON::ParserError
      # If it's HTML wrapping JSON (browser view), try to extract from <pre> tag
      if page_content.include?("<pre>")
        json_match = page_content.match(/<pre[^>]*>(.*?)<\/pre>/m)
        if json_match
          begin
            return JSON.parse(json_match[1])
          rescue JSON::ParserError
            # Not JSON in pre tag either
          end
        end
      end

      # Return raw content if not JSON
      Rails.logger.warn "[FlaresolverrService] Response is not JSON, returning raw content"
      page_content
    end
  rescue Errno::ECONNREFUSED
    raise FlaresolverrError, "Cannot connect to FlareSolverr at #{FLARESOLVERR_URL}. Is it running?"
  rescue Net::ReadTimeout
    raise FlaresolverrError, "FlareSolverr request timed out"
  end

  # Check if FlareSolverr is available
  def self.available?
    uri = URI(FLARESOLVERR_URL.sub("/v1", ""))
    response = Net::HTTP.get_response(uri)
    response.is_a?(Net::HTTPSuccess)
  rescue StandardError
    false
  end
end
