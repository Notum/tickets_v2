class AirbalticPriceHistory < ApplicationRecord
  belongs_to :airbaltic_flight_search

  scope :chronological, -> { order(:recorded_at) }
end
