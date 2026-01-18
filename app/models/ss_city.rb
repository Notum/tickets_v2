class SsCity < ApplicationRecord
  belongs_to :ss_region
  has_many :ss_flat_ads, dependent: :nullify
  has_many :ss_house_ads, dependent: :nullify

  validates :slug, presence: true
  validates :name_lv, presence: true
  validates :slug, uniqueness: { scope: :ss_region_id }

  scope :ordered, -> { order(:position, :name_lv) }

  def display_name
    name_lv
  end
end
