class SsFlatPriceHistory < ApplicationRecord
  belongs_to :ss_flat_ad

  validates :recorded_at, presence: true

  scope :recent, -> { order(recorded_at: :desc) }
  scope :chronological, -> { order(recorded_at: :asc) }
end
