# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TicketsV2 is a flight ticket price tracking application built with Rails 8.0 and Ruby 3.4.5. It monitors flight prices from six airlines (Ryanair, AirBaltic, Norwegian, Bode.lv charter flights, FlyDubai, Turkish Airlines) departing from Riga (RIX), tracks price history, and sends email notifications when prices drop.

## Common Commands

### Development
```bash
bin/dev              # Start development server with Tailwind CSS watching (uses foreman)
bin/rails server     # Start Rails server only
bin/setup            # Initial setup (bundle install, db:prepare, clear logs/tmp)
```

### Testing
```bash
bin/rails test                        # Run all tests
bin/rails test test/models/           # Run model tests
bin/rails test test/models/user_test.rb  # Run a single test file
bin/rails test test/models/user_test.rb:10  # Run a specific test by line number
bin/rails test:system                 # Run system tests (Capybara + Selenium)
```

### Code Quality
```bash
bin/rubocop          # Run RuboCop linter (uses rubocop-rails-omakase style)
bin/rubocop -a       # Auto-fix correctable offenses
bin/brakeman         # Run security scanner
```

### Database
```bash
bin/rails db:prepare    # Create and migrate (or just migrate if exists)
bin/rails db:migrate    # Run pending migrations
bin/rails db:seed       # Load seed data
```

### Background Jobs
```bash
bin/jobs             # Run Solid Queue job worker
```

### Airline Rake Tasks
```bash
bin/rails ryanair:sync_routes                          # Sync Ryanair destinations
bin/rails ryanair:list_destinations                    # List all Ryanair destinations
bin/rails ryanair:test_dates_out[DUB]                  # Test outbound dates to destination
bin/rails ryanair:test_dates_in[DUB]                   # Test return dates from destination
bin/rails ryanair:test_price_fetch[1]                  # Test price fetch for flight search ID
bin/rails airbaltic:sync_destinations                  # Sync AirBaltic destinations
bin/rails bode:sync_destinations                       # Sync Bode.lv destinations
bin/rails users:create[user@example.com]               # Create a new user
```

## Architecture

### Tech Stack
- **Frontend**: Hotwire (Turbo + Stimulus) with Tailwind CSS + DaisyUI via Propshaft asset pipeline
- **JavaScript**: ESM import maps (no Node.js/npm build step)
- **Database**: SQLite with Solid Cache, Solid Queue, and Solid Cable for caching, jobs, and WebSocket
- **Deployment**: Kamal-ready with Docker and Thruster for HTTP caching
- **Email**: Mailgun for delivery

### Domain Model
Each airline follows the same pattern with three models:
- `{Airline}Destination` - Airport/destination data synced from external APIs
- `{Airline}FlightSearch` - User's tracked flight (dates, prices, status)
- `{Airline}PriceHistory` - Historical price records for charting

Airlines: `Ryanair`, `Airbaltic`, `Norwegian`, `Bode` (charter flights), `Flydubai` (RIX-DXB only), `Turkish` (1-stop via Istanbul)

### Service Layer (`app/services/`)
Each airline has services namespaced under its name:
- `{Airline}::PriceFetchService` - Fetches current prices from airline API
- `{Airline}::DestinationsSyncService` or `RouteSyncService` - Syncs available destinations
- Date services for fetching available flight dates

### Background Jobs (`app/jobs/`)
Recurring jobs configured in `config/recurring.yml` (Solid Queue):
- `Sync{Airline}DestinationsJob` / `SyncRyanairRoutesJob` - Hourly destination sync
- `RefreshAll{Airline}PricesJob` - Hourly price refresh for all tracked flights
- `Fetch{Airline}PriceJob` - Single flight price fetch
- `CleanupExpiredFlightSearchesJob` - Daily cleanup of past flight searches

### Controllers
- `Tickets::{Airline}Controller` - CRUD for user's flight searches per airline
- `Api::{Airline}Controller` - AJAX endpoints for dynamic form data (destinations, dates)
- `SessionsController` - Email-based authentication (no password)
- `ProfilesController` - User settings (price notification threshold)

### Mailers
Price drop notifications and route change alerts are sent via:
- `{Airline}PriceDropMailer` - Notifies users when tracked flight prices drop
- `RyanairNewRouteMailer` / `RyanairRouteRemovedMailer` - Ryanair route changes
- `NorwegianNewRouteMailer` - Norwegian route changes

### Stimulus Controllers (`app/javascript/controllers/`)
- `{airline}_search_controller.js` - Dynamic flight search forms with cascading dropdowns
- `price_chart_controller.js` - Price history visualization

## Key Patterns

### Service Return Values
All price fetch services return a hash with `{ success: true/false, ... }`:
- On success: `{ success: true, price_out: ..., price_in: ..., total: ... }`
- On error: `{ success: false, error: "message" }`
- Price drops include: `{ ..., price_drop: { savings: ..., previous_price: ..., current_price: ... } }`

### Price Drop Notification Flow
1. `PriceFetchService` compares new total price with previous
2. If price dropped, returns `price_drop` hash in result
3. `RefreshAll{Airline}PricesJob` collects price drops and sends email via `{Airline}PriceDropMailer`

### External Dependencies

#### Byparr / FlareSolverr (Cloudflare Bypass)
Norwegian and FlyDubai APIs are protected by Cloudflare bot detection. We use [Byparr](https://github.com/ThePhaseless/Byparr) - a FlareSolverr-compatible proxy that uses Camoufox (Firefox-based) to solve Cloudflare challenges. Byparr is more reliable than FlareSolverr for our use case.

**Running locally (development):**
```bash
docker run -d --name flaresolverr -p 8191:8191 ghcr.io/thephaseless/byparr:latest
```

**Running in production:** See "Production Docker Setup" section below.

**Configuration:**
- `FLARESOLVERR_URL` env var (default: `http://localhost:8191/v1`)
- In production: `http://tickets_v2-flaresolverr:8191/v1` (Docker internal network)
- Timeout: 60 seconds per request

**Usage in code:**
- `FlaresolverrService` (`app/services/flaresolverr_service.rb`) wraps the API
- Used by Norwegian and FlyDubai services (date services, price fetch)
- `FlaresolverrService.available?` - check if service is running
- Raises `FlaresolverrService::FlaresolverrError` on failures

**Note:** The service is named `FlaresolverrService` for historical reasons, but Byparr uses the same API.

#### FlyDubai (RIX-DXB Route)
FlyDubai has a hardcoded single route (Riga to Dubai) with no destinations table:
- **Calendar API**: `GET https://www.flydubai.com/api/Calendar/RIX/DXB?fromDate=DD-Month-YYYY` (available flight dates)
- **Price API**: `POST https://flights2.flydubai.com/api/flights/1` with JSON payload containing search criteria
- Both APIs require FlareSolverr (Cloudflare protected)
- No destination sync job needed

**Price API Payload:**
```json
{
  "cabinClass": "Economy",
  "paxInfo": { "adultCount": 1, "childCount": 0, "infantCount": 0 },
  "searchCriteria": [
    { "date": "MM/DD/YYYY 12:00 AM", "dest": "DXB", "direction": "outBound", "origin": "RIX" },
    { "date": "MM/DD/YYYY 12:00 AM", "dest": "RIX", "direction": "inBound", "origin": "DXB" }
  ],
  "variant": "1"
}
```

#### Turkish Airlines (1-Stop via Istanbul)
Turkish Airlines flights are searched via a flight matrix API with 1-stop connections through Istanbul (IST):
- `Turkish::FlightMatrixService` - Fetches flight matrix/calendar data
- `Turkish::DestinationsSearchService` - Searches available destinations
- `Turkish::PriceFetchService` - Fetches prices for specific dates
- No destinations table (destinations searched dynamically)

## Key Configuration

- Our app is running locally (DEV) on port 4000
- If server restart is needed - ask user to do it. Do not try to initiate server restart/start by yourself
- All flights are from Riga (RIX) - this is hardcoded in services

## Production Docker Setup

### Docker Network
All containers run on the `kamal` Docker network for inter-container communication.

### Container Names
| Container | Image | Purpose |
|-----------|-------|---------|
| `tickets_v2-web-{commit_hash}` | `ghcr.io/notum/tickets_v2:{hash}` | Rails app (deployed via Kamal) |
| `tickets_v2-flaresolverr` | `ghcr.io/thephaseless/byparr:latest` | Cloudflare bypass proxy |
| `kamal-proxy` | `basecamp/kamal-proxy:v0.9.0` | HTTP proxy (ports 80, 443) |

### Starting Byparr in Production
```bash
docker run -d \
  --name tickets_v2-flaresolverr \
  --network kamal \
  -p 8191:8191 \
  ghcr.io/thephaseless/byparr:latest
```

### Restarting Byparr
```bash
docker stop tickets_v2-flaresolverr
docker rm tickets_v2-flaresolverr
docker run -d \
  --name tickets_v2-flaresolverr \
  --network kamal \
  -p 8191:8191 \
  ghcr.io/thephaseless/byparr:latest
```

### Useful Docker Commands
```bash
# Check running containers
docker ps

# View Byparr logs
docker logs tickets_v2-flaresolverr --tail 100

# Access Rails console in production
docker exec -it tickets_v2-web-{hash} bin/rails console

# Test Byparr is working
curl -X POST http://localhost:8191/v1 \
  -H "Content-Type: application/json" \
  -d '{"cmd": "request.get", "url": "https://www.norwegian.com", "maxTimeout": 60000}'
```

### Environment Variables (Production)
- `FLARESOLVERR_URL`: `http://tickets_v2-flaresolverr:8191/v1` - Uses Docker internal network hostname