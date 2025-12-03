class RyanairPriceHistory < ApplicationRecord
  belongs_to :ryanair_flight_search

  validates :total_price, presence: true
  validates :recorded_at, presence: true

  scope :chronological, -> { order(recorded_at: :asc) }
end
