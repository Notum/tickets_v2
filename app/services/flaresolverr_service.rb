require "net/http"
require "json"

class FlaresolverrService
  FLARESOLVERR_URL = ENV.fetch("FLARESOLVERR_URL", "http://localhost:8191/v1")
  MAX_TIMEOUT = 60_000 # 60 seconds

  class FlaresolverrError < StandardError; end

  # Session-based request: First GET a page to establish cookies, then POST to API
  # This is needed for APIs that require a valid session (like FlyDubai)
  def fetch_with_session(get_url, post_url, post_data, headers: nil)
    session_id = nil

    begin
      # Step 1: Create a session
      session_id = create_session
      Rails.logger.info "[FlaresolverrService] Created session: #{session_id}"

      # Step 2: GET the page to establish cookies
      Rails.logger.info "[FlaresolverrService] GET #{get_url} to establish session"
      get_with_session(get_url, session_id)

      sleep 1 # Small delay before POST

      # Step 3: POST to the API with the same session (cookies)
      Rails.logger.info "[FlaresolverrService] POST #{post_url} with session cookies"
      post_with_session(post_url, post_data, session_id, headers: headers)
    ensure
      # Step 4: Always destroy the session
      destroy_session(session_id) if session_id
    end
  end

  def create_session
    response = send_command({ cmd: "sessions.create" })
    response["session"] || raise(FlaresolverrError, "Failed to create session")
  end

  def destroy_session(session_id)
    send_command({ cmd: "sessions.destroy", session: session_id })
    Rails.logger.info "[FlaresolverrService] Destroyed session: #{session_id}"
  rescue StandardError => e
    Rails.logger.warn "[FlaresolverrService] Failed to destroy session: #{e.message}"
  end

  def get_with_session(url, session_id)
    response = send_command({
      cmd: "request.get",
      url: url,
      session: session_id,
      maxTimeout: MAX_TIMEOUT
    })

    parse_solution_response(response)
  end

  def post_with_session(url, post_data, session_id, headers: nil)
    command = {
      cmd: "request.post",
      url: url,
      session: session_id,
      maxTimeout: MAX_TIMEOUT,
      postData: post_data.is_a?(String) ? post_data : post_data.to_json
    }
    command[:headers] = headers if headers.present?

    response = send_command(command)
    parse_solution_response(response)
  end

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

  # POST request through FlareSolverr, bypassing Cloudflare protection
  # Returns parsed JSON if response is JSON, otherwise returns the raw HTML
  # Optional headers hash for APIs that require specific headers
  def post(url, post_data, headers: nil)
    Rails.logger.info "[FlaresolverrService] POST to: #{url}"

    uri = URI(FLARESOLVERR_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 120 # FlareSolverr can take a while

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/json"

    body = {
      cmd: "request.post",
      url: url,
      maxTimeout: MAX_TIMEOUT,
      postData: post_data.is_a?(String) ? post_data : post_data.to_json
    }

    # Add custom headers if provided
    body[:headers] = headers if headers.present?

    request.body = body.to_json

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

    Rails.logger.info "[FlaresolverrService] POST response (#{page_content.length} bytes), status: #{solution['status']}"

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
      Rails.logger.warn "[FlaresolverrService] POST response is not JSON, returning raw content"
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
    # Accept success (2xx) or redirect (3xx) as "available"
    response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPRedirection)
  rescue StandardError
    false
  end

  private

  def send_command(payload)
    uri = URI(FLARESOLVERR_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 120

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/json"
    request.body = payload.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise FlaresolverrError, "FlareSolverr returned HTTP #{response.code}: #{response.body.first(200)}"
    end

    result = JSON.parse(response.body)

    if result["status"] != "ok"
      raise FlaresolverrError, "FlareSolverr error: #{result['message']}"
    end

    result
  rescue Errno::ECONNREFUSED
    raise FlaresolverrError, "Cannot connect to FlareSolverr at #{FLARESOLVERR_URL}. Is it running?"
  rescue Net::ReadTimeout
    raise FlaresolverrError, "FlareSolverr request timed out"
  end

  def parse_solution_response(result)
    solution = result["solution"]
    page_content = solution["response"]

    Rails.logger.info "[FlaresolverrService] Response (#{page_content.length} bytes), status: #{solution['status']}"

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
  end
end
