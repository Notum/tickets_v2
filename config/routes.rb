Rails.application.routes.draw do
  # Authentication
  root "sessions#new"
  get "/login", to: "sessions#new"
  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy"

  # Profile
  get "/profile", to: "profiles#show", as: :profile
  patch "/profile", to: "profiles#update"

  # Admin - User Management
  resources :users, only: [ :index, :create, :destroy ]

  # Tickets
  scope :tickets, as: :tickets do
    # Bode.lv Charter Flights (prices refreshed hourly by system)
    get :bode, to: "tickets/bode#index"
    post :bode, to: "tickets/bode#create"
    delete "bode/:id", to: "tickets/bode#destroy", as: :bode_delete

    # Ryanair
    get :ryanair, to: "tickets/ryanair#index"
    post :ryanair, to: "tickets/ryanair#create"
    delete "ryanair/:id", to: "tickets/ryanair#destroy", as: :ryanair_delete
    post "ryanair/:id/refresh_price", to: "tickets/ryanair#refresh_price", as: :ryanair_refresh_price

    # AirBaltic
    get :airbaltic, to: "tickets/airbaltic#index"
    post :airbaltic, to: "tickets/airbaltic#create"
    delete "airbaltic/:id", to: "tickets/airbaltic#destroy", as: :airbaltic_delete
    post "airbaltic/:id/refresh_price", to: "tickets/airbaltic#refresh_price", as: :airbaltic_refresh_price

    # Norwegian
    get :norwegian, to: "tickets/norwegian#index"
    post :norwegian, to: "tickets/norwegian#create"
    delete "norwegian/:id", to: "tickets/norwegian#destroy", as: :norwegian_delete
    post "norwegian/:id/refresh_price", to: "tickets/norwegian#refresh_price", as: :norwegian_refresh_price

    # FlyDubai (RIX-DXB only)
    get :flydubai, to: "tickets/flydubai#index"
    post :flydubai, to: "tickets/flydubai#create"
    delete "flydubai/:id", to: "tickets/flydubai#destroy", as: :flydubai_delete
    post "flydubai/:id/refresh_price", to: "tickets/flydubai#refresh_price", as: :flydubai_refresh_price

    # Turkish Airlines (1-stop via Istanbul)
    get :turkish, to: "tickets/turkish#index"
    post :turkish, to: "tickets/turkish#create"
    delete "turkish/:id", to: "tickets/turkish#destroy", as: :turkish_delete
    post "turkish/:id/refresh_price", to: "tickets/turkish#refresh_price", as: :turkish_refresh_price
  end

  # Accommodation
  scope :accommodation, as: :accommodation do
    # Booking.com Hotels
    get :booking, to: "accommodation/booking#index"
    post :booking, to: "accommodation/booking#create"
    delete "booking/:id", to: "accommodation/booking#destroy", as: :booking_delete
    post "booking/:id/refresh_price", to: "accommodation/booking#refresh_price", as: :booking_refresh_price
  end

  # SS.COM Real Estate
  scope :sscom, as: :sscom do
    # Flats
    get :flats, to: "sscom/flats#index"
    post "flats/search", to: "sscom/flats#search"
    post "flats/follow_by_url", to: "sscom/flats#follow_by_url", as: :flats_follow_by_url
    post "flats/:id/follow", to: "sscom/flats#follow", as: :flats_follow
    delete "flats/:id/unfollow", to: "sscom/flats#unfollow", as: :flats_unfollow

    # Houses
    get :houses, to: "sscom/houses#index"
    post "houses/search", to: "sscom/houses#search"
    post "houses/follow_by_url", to: "sscom/houses#follow_by_url", as: :houses_follow_by_url
    post "houses/:id/follow", to: "sscom/houses#follow", as: :houses_follow
    delete "houses/:id/unfollow", to: "sscom/houses#unfollow", as: :houses_unfollow
  end

  # API endpoints (AJAX)
  namespace :api do
    # Ryanair
    get "ryanair/destinations", to: "ryanair#destinations"
    get "ryanair/dates_out", to: "ryanair#dates_out"
    get "ryanair/dates_in", to: "ryanair#dates_in"
    post "ryanair/flight_searches", to: "ryanair#flight_searches"

    # AirBaltic
    get "airbaltic/destinations", to: "airbaltic#destinations"
    get "airbaltic/dates_out", to: "airbaltic#dates_out"
    get "airbaltic/dates_in", to: "airbaltic#dates_in"

    # Bode.lv
    get "bode/destinations", to: "bode#destinations"
    get "bode/flights", to: "bode#flights"

    # Norwegian
    get "norwegian/destinations", to: "norwegian#destinations"
    get "norwegian/dates_out", to: "norwegian#dates_out"
    get "norwegian/dates_in", to: "norwegian#dates_in"

    # FlyDubai (no destinations - hardcoded RIX-DXB)
    get "flydubai/dates_out", to: "flydubai#dates_out"
    get "flydubai/dates_in", to: "flydubai#dates_in"

    # Turkish Airlines
    get "turkish/destinations", to: "turkish#destinations"
    post "turkish/flight_matrix", to: "turkish#flight_matrix"

    # Booking.com
    get "booking/search_hotels", to: "booking#search_hotels"
    get "booking/fetch_rooms", to: "booking#fetch_rooms"

    # SS.COM Real Estate
    get "sscom/regions", to: "sscom#regions"
    get "sscom/cities", to: "sscom#cities"
    post "sscom/search_flats", to: "sscom#search_flats"
    post "sscom/search_houses", to: "sscom#search_houses"

    # User Preferences
    patch "user_preferences/accordion_state", to: "user_preferences#update_accordion_state"
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
