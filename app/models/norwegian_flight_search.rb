class NorwegianFlightSearch < ApplicationRecord
  belongs_to :user
  belongs_to :norwegian_destination
  has_many :price_histories, class_name: "NorwegianPriceHistory", dependent: :destroy

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

  def direct_flight?
    is_direct_out == true && is_direct_in == true
  end

  def record_price_if_changed(new_price_out, new_price_in, new_total_price)
    last_history = price_histories.order(recorded_at: :desc).first

    # Record if this is the first price or if total price changed
    if last_history.nil? || last_history.total_price != new_total_price
      price_histories.create!(
        price_out: new_price_out,
        price_in: new_price_in,
        total_price: new_total_price,
        recorded_at: Time.current
      )
    end
  end

  def price_history_for_chart
    price_histories.chronological.pluck(:recorded_at, :total_price).map do |recorded_at, price|
      { x: recorded_at.to_i * 1000, y: price.to_f }
    end
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
