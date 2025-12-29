class TurkishPriceHistory < ApplicationRecord
  belongs_to :turkish_flight_search

  scope :chronological, -> { order(recorded_at: :asc) }
end
