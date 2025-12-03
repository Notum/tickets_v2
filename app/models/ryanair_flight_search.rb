class RyanairFlightSearch < ApplicationRecord
  belongs_to :user
  belongs_to :ryanair_destination

  validates :date_out, presence: true
  validates :date_in, presence: true
  validate :date_in_after_date_out

  before_save :calculate_total_price

  scope :recent, -> { order(created_at: :desc) }
  scope :priced, -> { where(status: "priced") }
  scope :pending, -> { where(status: "pending") }

  def trip_duration
    return 0 unless date_out && date_in
    (date_in - date_out).to_i
  end

  def priced?
    status == "priced"
  end

  def pending?
    status == "pending"
  end

  def error?
    status == "error"
  end

  private

  def date_in_after_date_out
    return unless date_out && date_in
    if date_in <= date_out
      errors.add(:date_in, "must be after departure date")
    end
  end

  def calculate_total_price
    if price_out.present? && price_in.present?
      self.total_price = price_out + price_in
    end
  end
end
