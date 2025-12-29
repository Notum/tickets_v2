class NorwegianPriceHistory < ApplicationRecord
  belongs_to :norwegian_flight_search

  scope :chronological, -> { order(:recorded_at) }
end
