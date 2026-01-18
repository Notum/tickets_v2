class SsRegion < ApplicationRecord
  has_many :ss_cities, dependent: :destroy
  has_many :ss_flat_ads, dependent: :destroy
  has_many :ss_house_ads, dependent: :destroy

  belongs_to :parent, class_name: "SsRegion", foreign_key: :parent_slug, primary_key: :slug, optional: true
  has_many :children, class_name: "SsRegion", foreign_key: :parent_slug, primary_key: :slug

  validates :slug, presence: true, uniqueness: true
  validates :name_lv, presence: true

  scope :ordered, -> { order(:position, :name_lv) }
  scope :top_level, -> { where(parent_slug: nil) }

  def display_name
    name_lv
  end

  def full_path
    parent ? "#{parent.full_path} > #{name_lv}" : name_lv
  end
end
