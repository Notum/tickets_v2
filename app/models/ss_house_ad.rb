class SsHouseAd < ApplicationRecord
  DEAL_TYPES = %w[sell buy rent_out rent_want exchange].freeze

  belongs_to :ss_region
  belongs_to :ss_city, optional: true
  has_many :ss_house_follows, dependent: :destroy
  has_many :followers, through: :ss_house_follows, source: :user
  has_many :price_histories, class_name: "SsHousePriceHistory", dependent: :destroy

  validates :external_id, presence: true, uniqueness: true
  validates :content_hash, presence: true
  validates :deal_type, presence: true, inclusion: { in: DEAL_TYPES }
  validates :original_url, presence: true

  scope :active, -> { where(active: true) }
  scope :selling, -> { where(deal_type: "sell") }
  scope :renting_out, -> { where(deal_type: "rent_out") }
  scope :recent, -> { order(posted_at: :desc) }
  scope :by_price, -> { order(:price) }
  scope :by_price_desc, -> { order(price: :desc) }

  before_validation :generate_content_hash, if: :should_regenerate_hash?

  def display_title
    title.presence || "#{rooms}-room house in #{street.presence || ss_city&.name_lv || ss_region.name_lv}"
  end

  def location_display
    [street, ss_city&.name_lv, ss_region.name_lv].compact.join(", ")
  end

  def record_price_if_changed(new_price, new_price_per_m2 = nil)
    last_history = price_histories.order(recorded_at: :desc).first

    if last_history.nil? || last_history.price != new_price
      price_histories.create!(
        price: new_price,
        price_per_m2: new_price_per_m2,
        recorded_at: Time.current
      )
      true
    else
      false
    end
  end

  def price_history_for_chart
    price_histories.order(recorded_at: :asc).pluck(:recorded_at, :price).map do |recorded_at, price|
      { x: recorded_at.to_i * 1000, y: price.to_f }
    end
  end

  def price_change_since_follow(follow)
    return nil unless follow.price_at_follow && price
    price - follow.price_at_follow
  end

  def price_change_percentage_since_follow(follow)
    return nil unless follow.price_at_follow && follow.price_at_follow > 0 && price
    ((price - follow.price_at_follow) / follow.price_at_follow * 100).round(1)
  end

  private

  def generate_content_hash
    hash_content = [
      ss_region_id,
      ss_city_id,
      street&.downcase&.strip,
      rooms,
      area&.round(1),
      land_area&.round(1),
      floors,
      house_type
    ].join("|")
    self.content_hash = Digest::SHA256.hexdigest(hash_content)
  end

  def should_regenerate_hash?
    new_record? || ss_region_id_changed? || ss_city_id_changed? ||
      street_changed? || rooms_changed? || area_changed? ||
      land_area_changed? || floors_changed? || house_type_changed?
  end
end
