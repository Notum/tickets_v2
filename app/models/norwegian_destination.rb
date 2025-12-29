class NorwegianDestination < ApplicationRecord
  has_many :norwegian_flight_searches, dependent: :destroy

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true

  scope :ordered, -> { order(:name) }
  scope :active, -> { where(active: true) }

  def display_name
    "#{name} (#{code})"
  end
end
