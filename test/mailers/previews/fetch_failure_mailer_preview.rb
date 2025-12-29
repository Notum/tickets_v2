class FetchFailureMailerPreview < ActionMailer::Preview
  def fetch_failed
    failures = [
      {
        flight_search_id: 42,
        destination: "BCN",
        dates: "15 Jan - 22 Jan 2025",
        error: "API timeout after 30 seconds"
      },
      {
        flight_search_id: 87,
        destination: "DUB",
        dates: "20 Feb - 27 Feb 2025",
        error: "Invalid response format: expected JSON but got HTML"
      },
      {
        flight_search_id: 123,
        destination: "STN",
        dates: "10 Mar - 17 Mar 2025",
        error: "HTTP 503 Service Unavailable"
      }
    ]

    FetchFailureMailer.fetch_failed(airline: "Ryanair", failures: failures)
  end

  def fetch_failed_flaresolverr
    failures = [
      {
        flight_search_id: 15,
        destination: "OSL",
        dates: "05 Apr - 12 Apr 2025",
        error: "FlareSolverr unavailable: Connection refused"
      },
      {
        flight_search_id: 28,
        destination: "CPH",
        dates: "18 May - 25 May 2025",
        error: "FlareSolverr timeout: Cloudflare challenge not solved within 60s"
      }
    ]

    FetchFailureMailer.fetch_failed(airline: "Norwegian", failures: failures)
  end

  def fetch_failed_single
    failures = [
      {
        flight_search_id: 5,
        destination: "DXB",
        dates: "01 Jun - 15 Jun 2025",
        error: "No flights available for selected dates"
      }
    ]

    FetchFailureMailer.fetch_failed(airline: "FlyDubai", failures: failures)
  end
end
