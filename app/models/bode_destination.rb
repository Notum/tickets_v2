class BodeDestination < ApplicationRecord
  has_many :bode_flight_searches, dependent: :destroy

  validates :name, presence: true
  validates :charter_path, presence: true, uniqueness: true

  scope :ordered, -> { order(:name) }

  def display_name
    name
  end

  def full_url
    "https://bode.lv#{charter_path}"
  end
end
