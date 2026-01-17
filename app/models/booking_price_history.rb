class BookingPriceHistory < ApplicationRecord
  belongs_to :booking_search

  validates :price, presence: true
  validates :recorded_at, presence: true

  scope :chronological, -> { order(recorded_at: :asc) }
end
