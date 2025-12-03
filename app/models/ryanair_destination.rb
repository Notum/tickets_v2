class RyanairDestination < ApplicationRecord
  has_many :ryanair_flight_searches, dependent: :destroy

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true

  scope :active, -> { where(seasonal: false) }
  scope :ordered, -> { order(:name) }

  def display_name
    "#{name} (#{code})"
  end
end
