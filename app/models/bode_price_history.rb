class BodePriceHistory < ApplicationRecord
  belongs_to :bode_flight_search

  validates :price, presence: true
  validates :recorded_at, presence: true

  scope :chronological, -> { order(recorded_at: :asc) }
end
