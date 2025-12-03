# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Rails 8.0 application called TicketsV2 using Ruby 3.4.5. It's a fresh Rails app with Hotwire (Turbo + Stimulus), Tailwind CSS, and SQLite database.

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

## Architecture

- **Frontend**: Hotwire (Turbo + Stimulus) with Tailwind CSS via Propshaft asset pipeline
- **JavaScript**: ESM import maps (no Node.js/npm build step)
- **Database**: SQLite with Solid Cache, Solid Queue, and Solid Cable for caching, jobs, and WebSocket
- **Deployment**: Kamal-ready with Docker and Thruster for HTTP caching

## Key Directories

- `app/javascript/controllers/` - Stimulus controllers
- `app/assets/tailwind/application.css` - Tailwind entry point
- `db/` - SQLite databases and schemas (including cache, queue, cable schemas)
