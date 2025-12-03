Rails.application.routes.draw do
  # Authentication
  root "sessions#new"
  get "/login", to: "sessions#new"
  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy"

  # Dashboards
  scope :dashboards, as: :dashboards do
    get :bode, to: "dashboards#bode"
    get :ryanair, to: "dashboards#ryanair"
    get :airbaltic, to: "dashboards#airbaltic"
    get :norwegian, to: "dashboards#norwegian"
    get :salidzini, to: "dashboards#salidzini"
  end

  # Tickets
  scope :tickets, as: :tickets do
    get :bode, to: "tickets#bode"
    get :ryanair, to: "tickets/ryanair#index"
    post :ryanair, to: "tickets/ryanair#create"
    delete "ryanair/:id", to: "tickets/ryanair#destroy", as: :ryanair_delete
    post "ryanair/:id/refresh_price", to: "tickets/ryanair#refresh_price", as: :ryanair_refresh_price
    get :airbaltic, to: "tickets#airbaltic"
    get :norwegian, to: "tickets#norwegian"
  end

  # Ryanair API endpoints (AJAX)
  namespace :api do
    get "ryanair/destinations", to: "ryanair#destinations"
    get "ryanair/dates_out", to: "ryanair#dates_out"
    get "ryanair/dates_in", to: "ryanair#dates_in"
    post "ryanair/flight_searches", to: "ryanair#flight_searches"
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
