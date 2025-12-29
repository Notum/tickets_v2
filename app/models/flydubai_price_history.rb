class FlydubaiPriceHistory < ApplicationRecord
  belongs_to :flydubai_flight_search

  scope :chronological, -> { order(:recorded_at) }
end
