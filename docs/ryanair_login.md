# Ryanair Flight Search Implementation Plan

## Overview

This document outlines the step-by-step implementation plan for the Ryanair flight search feature in TicketsV2. The system allows users to log in via email, browse Ryanair destinations from Riga, select flight dates, and save flight searches with pricing.

---

## Phase 1: Authentication System

### 1.1 User Model & Migration

**File:** `db/migrate/XXXXXX_create_users.rb`

```ruby
create_table :users do |t|
  t.string :email, null: false, index: { unique: true }
  t.timestamps
end
```

**File:** `app/models/user.rb`

- Add email validation (presence, uniqueness, format)
- No password fields needed

### 1.2 Sessions Controller

**File:** `app/controllers/sessions_controller.rb`

- `new` action: Render login form
- `create` action:
  - Find user by email (case-insensitive)
  - If found: Store `user_id` in session, redirect to dashboard
  - If not found: Flash error "User not found. Please contact administrator."
- `destroy` action: Clear session, redirect to login

### 1.3 Login View

**File:** `app/views/sessions/new.html.erb`

- Simple form with email input field only
- Styled with Tailwind CSS
- Error message display area

### 1.4 Routes Configuration

**File:** `config/routes.rb`

```ruby
root "sessions#new"

get "/login", to: "sessions#new"
post "/login", to: "sessions#create"
delete "/logout", to: "sessions#destroy"
```

### 1.5 Application Controller Authentication

**File:** `app/controllers/application_controller.rb`

- Add `current_user` helper method
- Add `authenticate_user!` before_action
- Add `logged_in?` helper

### 1.6 Rake Task: Create User

**File:** `lib/tasks/users.rake`

```ruby
namespace :users do
  desc "Create a new user by email"
  task :create, [:email] => :environment do |t, args|
    # Validate email format
    # Create user
    # Output success/error message
  end
end
```

**Usage:** `bin/rails users:create[user@example.com]`

---

## Phase 2: Ryanair Destinations Sync

### 2.1 Destination Model & Migration

**File:** `db/migrate/XXXXXX_create_ryanair_destinations.rb`

```ruby
create_table :ryanair_destinations do |t|
  t.string :code, null: false, index: { unique: true }  # Airport code (e.g., "DUB")
  t.string :name, null: false                            # Airport name
  t.string :seo_name                                     # SEO-friendly name
  t.string :city_name                                    # City name
  t.string :city_code                                    # City code
  t.string :country_name                                 # Country name
  t.string :country_code                                 # Country code (e.g., "IE")
  t.string :currency_code                                # Currency (e.g., "EUR")
  t.decimal :latitude, precision: 10, scale: 6
  t.decimal :longitude, precision: 10, scale: 6
  t.string :timezone
  t.boolean :is_base, default: false
  t.boolean :seasonal, default: false
  t.datetime :last_synced_at
  t.timestamps
end
```

**File:** `app/models/ryanair_destination.rb`

- Validations for code, name
- Scope `active` for available destinations

### 2.2 Ryanair API Service

**File:** `app/services/ryanair/routes_sync_service.rb`

```ruby
module Ryanair
  class RoutesSyncService
    ROUTES_API_URL = "https://www.ryanair.com/api/views/locate/searchWidget/routes/en/airport/RIX"

    def call
      # Fetch JSON from API
      # Parse response
      # Upsert destinations (create or update by code)
      # Log sync results
    end
  end
end
```

### 2.3 Background Job for Sync

**File:** `app/jobs/sync_ryanair_routes_job.rb`

```ruby
class SyncRyanairRoutesJob < ApplicationJob
  queue_as :default

  def perform
    Ryanair::RoutesSyncService.new.call
  end
end
```

### 2.4 Recurring Job Configuration (Solid Queue)

**File:** `config/recurring.yml`

```yaml
sync_ryanair_routes:
  class: SyncRyanairRoutesJob
  schedule: every hour
```

### 2.5 Rake Task for Manual Sync

**File:** `lib/tasks/ryanair.rake`

```ruby
namespace :ryanair do
  desc "Sync Ryanair destinations from RIX"
  task sync_routes: :environment do
    Ryanair::RoutesSyncService.new.call
  end
end
```

**Usage:** `bin/rails ryanair:sync_routes`

---

## Phase 3: Navigation & Layout

### 3.1 Application Layout Update

**File:** `app/views/layouts/application.html.erb`

- Conditional rendering: Show navigation only when logged in
- Include navigation partial for authenticated users

### 3.2 Top Navigation Partial

**File:** `app/views/shared/_top_navigation.html.erb`

Tailwind-styled navigation with:

- **Dashboards** dropdown:
  - Bode.lv (`/dashboards/bode`)
  - Ryanair (`/dashboards/ryanair`)
  - AirBaltic (`/dashboards/airbaltic`)
  - Norwegian (`/dashboards/norwegian`)
  - Salidzini (`/dashboards/salidzini`)

- **Tickets** dropdown:
  - Bode.lv (`/tickets/bode`)
  - Ryanair (`/tickets/ryanair`)
  - AirBaltic (`/tickets/airbaltic`)
  - Norwegian (`/tickets/norwegian`)

- Logout button

### 3.3 Stimulus Controller for Dropdowns

**File:** `app/javascript/controllers/dropdown_controller.js`

- Toggle dropdown visibility on click
- Close dropdown when clicking outside
- Handle keyboard navigation (optional)

### 3.4 Placeholder Controllers & Views

Create placeholder controllers and views for navigation links:

**Controllers:**
- `app/controllers/dashboards_controller.rb` (actions: bode, ryanair, airbaltic, norwegian, salidzini)
- `app/controllers/tickets_controller.rb` (actions: bode, ryanair, airbaltic, norwegian)

**Views:**
- Placeholder views for each action

**Routes:**
```ruby
namespace :dashboards do
  get :bode
  get :ryanair
  # etc.
end

namespace :tickets do
  get :bode
  get :ryanair
  # etc.
end
```

---

## Phase 4: Ryanair Tickets Page (Flight Search)

### 4.1 Flight Search Model & Migration

**File:** `db/migrate/XXXXXX_create_ryanair_flight_searches.rb`

```ruby
create_table :ryanair_flight_searches do |t|
  t.references :user, null: false, foreign_key: true
  t.references :ryanair_destination, null: false, foreign_key: true
  t.date :date_out, null: false           # Outbound flight date
  t.date :date_in, null: false            # Return flight date
  t.decimal :price_out, precision: 10, scale: 2    # Outbound base fare
  t.decimal :price_in, precision: 10, scale: 2     # Return base fare
  t.decimal :total_price, precision: 10, scale: 2  # Calculated sum
  t.string :status, default: 'pending'    # pending, priced, error
  t.text :api_response                    # Store raw API response (JSON)
  t.datetime :priced_at                   # When prices were fetched
  t.timestamps
end
```

**File:** `app/models/ryanair_flight_search.rb`

- Belongs to user
- Belongs to ryanair_destination
- Calculate total_price before save
- Validations

### 4.2 Ryanair Tickets Controller

**File:** `app/controllers/tickets/ryanair_controller.rb`

```ruby
module Tickets
  class RyanairController < ApplicationController
    before_action :authenticate_user!

    def index
      @destinations = RyanairDestination.order(:name)
      @saved_searches = current_user.ryanair_flight_searches.includes(:ryanair_destination)
    end

    def available_dates_out
      # AJAX endpoint
      # Params: destination_code
      # Call Ryanair API for outbound dates
      # Return JSON
    end

    def available_dates_in
      # AJAX endpoint
      # Params: destination_code, date_out
      # Call Ryanair API for return dates
      # Return JSON
    end

    def create
      # Save flight search
      # Trigger price fetch job
    end
  end
end
```

### 4.3 Ryanair Tickets View

**File:** `app/views/tickets/ryanair/index.html.erb`

Layout with Tailwind CSS:

1. **Destination Select Dropdown**
   - Populated from `RyanairDestination.all`
   - On change: Fetch available outbound dates

2. **Date Out Select** (initially hidden/disabled)
   - Populated via AJAX when destination selected
   - On change: Fetch available return dates

3. **Date In Select** (initially hidden/disabled)
   - Populated via AJAX when date_out selected
   - Shows trip duration calculation

4. **Save Button**
   - Creates flight search record
   - Triggers price fetch

5. **Saved Searches Table**
   - List of user's saved flight searches
   - Shows: Destination, Date Out, Date In, Price Out, Price In, Total, Status

### 4.4 Stimulus Controller for Flight Search

**File:** `app/javascript/controllers/ryanair_search_controller.js`

- Handle destination selection ’ fetch outbound dates
- Handle outbound date selection ’ fetch return dates
- Calculate and display trip duration
- Handle form submission
- Show loading states

---

## Phase 5: Ryanair Date Availability API Services

### 5.1 Outbound Dates Service

**File:** `app/services/ryanair/outbound_dates_service.rb`

```ruby
module Ryanair
  class OutboundDatesService
    # API: https://www.ryanair.com/api/farfnd/3/oneWayFares/RIX/{destination_code}/availabilities

    def initialize(destination_code)
      @destination_code = destination_code
    end

    def call
      # Fetch from API
      # Parse dates from response
      # Return array of available dates
    end
  end
end
```

### 5.2 Return Dates Service

**File:** `app/services/ryanair/return_dates_service.rb`

```ruby
module Ryanair
  class ReturnDatesService
    # API: https://www.ryanair.com/api/farfnd/3/oneWayFares/{destination_code}/RIX/availabilities

    def initialize(destination_code)
      @destination_code = destination_code
    end

    def call
      # Fetch from API
      # Parse dates from response
      # Return array of available dates
    end
  end
end
```

---

## Phase 6: Price Fetch with Browser Automation

### 6.1 Add Required Gems

**File:** `Gemfile`

```ruby
gem "selenium-webdriver"   # For headless browser
gem "webdrivers"           # Auto-manage ChromeDriver
```

### 6.2 Cookie Fetcher Service

**File:** `app/services/ryanair/cookie_fetcher_service.rb`

```ruby
module Ryanair
  class CookieFetcherService
    RYANAIR_URL = "https://www.ryanair.com"

    def call
      # Launch headless Chrome
      # Navigate to ryanair.com
      # Wait for page load (handle cookie consent if needed)
      # Extract all cookies
      # Return cookies hash/string for API calls
      # Close browser
    end
  end
end
```

### 6.3 Price Fetch Service

**File:** `app/services/ryanair/price_fetch_service.rb`

```ruby
module Ryanair
  class PriceFetchService
    AVAILABILITY_API = "https://www.ryanair.com/api/booking/v4/en-lv/availability"

    def initialize(flight_search)
      @flight_search = flight_search
    end

    def call
      # Get fresh cookies via CookieFetcherService
      # Build API URL with params:
      #   ADT=1, TEEN=0, CHD=0, INF=0
      #   Origin=RIX
      #   Destination=@flight_search.destination.code
      #   DateOut=@flight_search.date_out
      #   DateIn=@flight_search.date_in
      #   FlexDaysBeforeOut=2, FlexDaysOut=2
      #   FlexDaysBeforeIn=2, FlexDaysIn=2
      #   RoundTrip=true
      #   ToUs=AGREED
      # Make HTTP request with cookies
      # Parse response
      # Extract base fare prices (out and in)
      # Update flight_search record
    end
  end
end
```

### 6.4 Price Fetch Job

**File:** `app/jobs/fetch_ryanair_price_job.rb`

```ruby
class FetchRyanairPriceJob < ApplicationJob
  queue_as :default

  def perform(flight_search_id)
    flight_search = RyanairFlightSearch.find(flight_search_id)
    Ryanair::PriceFetchService.new(flight_search).call
  end
end
```

---

## Phase 7: Testing Rake Tasks

### 7.1 Test Flight Search Rake Task

**File:** `lib/tasks/ryanair.rake`

```ruby
namespace :ryanair do
  desc "Test price fetch for a saved flight search"
  task :test_price_fetch, [:flight_search_id] => :environment do |t, args|
    flight_search = RyanairFlightSearch.find(args[:flight_search_id])

    puts "Testing price fetch for:"
    puts "  Destination: #{flight_search.ryanair_destination.name}"
    puts "  Date Out: #{flight_search.date_out}"
    puts "  Date In: #{flight_search.date_in}"
    puts ""

    result = Ryanair::PriceFetchService.new(flight_search).call

    puts "Result:"
    puts "  Price Out: #{flight_search.reload.price_out}"
    puts "  Price In: #{flight_search.price_in}"
    puts "  Total: #{flight_search.total_price}"
    puts "  Status: #{flight_search.status}"
  end

  desc "Test outbound dates for a destination"
  task :test_dates_out, [:destination_code] => :environment do |t, args|
    dates = Ryanair::OutboundDatesService.new(args[:destination_code]).call
    puts "Available outbound dates from RIX to #{args[:destination_code]}:"
    dates.each { |d| puts "  #{d}" }
  end

  desc "Test return dates for a destination"
  task :test_dates_in, [:destination_code] => :environment do |t, args|
    dates = Ryanair::ReturnDatesService.new(args[:destination_code]).call
    puts "Available return dates from #{args[:destination_code]} to RIX:"
    dates.each { |d| puts "  #{d}" }
  end
end
```

**Usage:**
- `bin/rails ryanair:test_price_fetch[1]` - Test price fetch for flight search ID 1
- `bin/rails ryanair:test_dates_out[DUB]` - Test outbound dates to Dublin
- `bin/rails ryanair:test_dates_in[DUB]` - Test return dates from Dublin

---

## Phase 8: Routes Summary

**File:** `config/routes.rb`

```ruby
Rails.application.routes.draw do
  # Authentication
  root "sessions#new"
  get "/login", to: "sessions#new"
  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy"

  # Dashboards (placeholder)
  scope :dashboards do
    get :bode, to: "dashboards#bode"
    get :ryanair, to: "dashboards#ryanair"
    get :airbaltic, to: "dashboards#airbaltic"
    get :norwegian, to: "dashboards#norwegian"
    get :salidzini, to: "dashboards#salidzini"
  end

  # Tickets
  scope :tickets do
    get :bode, to: "tickets#bode"
    get :ryanair, to: "tickets/ryanair#index"
    get :airbaltic, to: "tickets#airbaltic"
    get :norwegian, to: "tickets#norwegian"
  end

  # Ryanair API endpoints (AJAX)
  namespace :api do
    namespace :ryanair do
      get :destinations
      get :dates_out
      get :dates_in
      post :flight_searches
    end
  end
end
```

---

## Database Schema Summary

### Tables:

1. **users**
   - id, email, created_at, updated_at

2. **ryanair_destinations**
   - id, code, name, seo_name, city_name, city_code, country_name, country_code, currency_code, latitude, longitude, timezone, is_base, seasonal, last_synced_at, created_at, updated_at

3. **ryanair_flight_searches**
   - id, user_id, ryanair_destination_id, date_out, date_in, price_out, price_in, total_price, status, api_response, priced_at, created_at, updated_at

---

## Implementation Order

1. **Phase 1** - Authentication (User model, sessions, login page, rake task)
2. **Phase 2** - Destinations sync (Model, API service, background job)
3. **Phase 3** - Navigation & Layout (Top nav, placeholder pages)
4. **Phase 4** - Ryanair tickets page (UI, Stimulus controller)
5. **Phase 5** - Date availability APIs (Outbound/Return date services)
6. **Phase 6** - Price fetch with cookies (Selenium, price service)
7. **Phase 7** - Testing rake tasks

---

## Dependencies

### Gems to Add:

```ruby
# Gemfile
gem "selenium-webdriver"   # Headless browser for cookie fetching
gem "webdrivers"           # ChromeDriver management
```

### System Requirements:

- Chrome or Chromium browser installed
- ChromeDriver (auto-managed by webdrivers gem)

---

## Notes

- All API calls to Ryanair should include proper error handling and logging
- Cookie fetching may need adjustment based on Ryanair's anti-bot measures
- Consider rate limiting API calls to avoid being blocked
- Store API responses for debugging purposes
- The price fetch uses FlexDays parameters (2 days before/after) - prices returned may be for flexible dates
