class SsFlatFollow < ApplicationRecord
  STATUSES = %w[active removed].freeze

  belongs_to :user
  belongs_to :ss_flat_ad

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :user_id, uniqueness: { scope: :ss_flat_ad_id }

  scope :active, -> { where(status: "active") }
  scope :removed, -> { where(status: "removed") }

  before_create :set_price_at_follow

  def active?
    status == "active"
  end

  def removed?
    status == "removed"
  end

  def mark_as_removed!
    update!(status: "removed")
  end

  def mark_as_active!
    update!(status: "active")
  end

  def price_dropped?
    return false unless price_at_follow && ss_flat_ad.price
    ss_flat_ad.price < price_at_follow
  end

  def price_drop_amount
    return nil unless price_dropped?
    price_at_follow - ss_flat_ad.price
  end

  def price_drop_percentage
    return nil unless price_dropped? && price_at_follow > 0
    ((price_at_follow - ss_flat_ad.price) / price_at_follow * 100).round(1)
  end

  private

  def set_price_at_follow
    self.price_at_follow ||= ss_flat_ad.price
  end
end
