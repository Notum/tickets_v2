class BodeFlightPriceHistory < ApplicationRecord
  belongs_to :bode_flight

  validates :price, presence: true
  validates :recorded_at, presence: true

  scope :chronological, -> { order(recorded_at: :asc) }
end
