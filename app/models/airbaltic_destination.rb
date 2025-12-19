class AirbalticDestination < ApplicationRecord
  has_many :airbaltic_flight_searches, dependent: :destroy

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true

  scope :ordered, -> { order(:name) }
  scope :active, -> { where(active: true) }

  def display_name
    "#{name} (#{code})"
  end
end
