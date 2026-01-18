class SsHousePriceHistory < ApplicationRecord
  belongs_to :ss_house_ad

  validates :recorded_at, presence: true

  scope :recent, -> { order(recorded_at: :desc) }
  scope :chronological, -> { order(recorded_at: :asc) }
end
