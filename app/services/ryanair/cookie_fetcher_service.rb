require "selenium-webdriver"

module Ryanair
  class CookieFetcherService
    RYANAIR_URL = "https://www.ryanair.com".freeze

    def call
      Rails.logger.info "[Ryanair::CookieFetcherService] Starting headless browser to fetch cookies..."

      driver = create_driver
      cookies = fetch_cookies(driver)

      Rails.logger.info "[Ryanair::CookieFetcherService] Successfully fetched #{cookies.size} cookies"

      cookies
    rescue StandardError => e
      Rails.logger.error "[Ryanair::CookieFetcherService] Error: #{e.message}"
      {}
    ensure
      driver&.quit
    end

    private

    def create_driver
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument("--headless=new")
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
      options.add_argument("--disable-gpu")
      options.add_argument("--window-size=1920,1080")
      options.add_argument("--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

      Selenium::WebDriver.for(:chrome, options: options)
    end

    def fetch_cookies(driver)
      driver.navigate.to(RYANAIR_URL)

      # Wait for page to load and potentially accept cookie consent
      sleep 3

      # Try to accept cookie consent if present
      begin
        accept_button = driver.find_element(:css, "[data-ref='cookie.accept-all'], .cookie-popup-with-overlay__button")
        accept_button.click if accept_button
        sleep 1
      rescue Selenium::WebDriver::Error::NoSuchElementError
        # Cookie consent not found, continue
      end

      # Wait a bit more for cookies to be set
      sleep 2

      # Extract cookies
      driver.manage.all_cookies.each_with_object({}) do |cookie, hash|
        hash[cookie[:name]] = cookie[:value]
      end
    end
  end
end
