class BodeFlightSearch < ApplicationRecord
  belongs_to :user
  belongs_to :bode_destination
  belongs_to :bode_flight, optional: true
  has_many :price_histories, class_name: "BodePriceHistory", dependent: :destroy

  validates :date_out, presence: true
  validates :date_in, presence: true
  validate :date_in_after_date_out

  scope :recent, -> { order(created_at: :desc) }
  scope :priced, -> { where(status: "priced") }
  scope :pending, -> { where(status: "pending") }

  def trip_duration
    nights || (date_in && date_out ? (date_in - date_out).to_i : 0)
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

  def unavailable?
    status == "unavailable"
  end

  def record_price_if_changed(new_price)
    last_history = price_histories.order(recorded_at: :desc).first

    if last_history.nil? || last_history.price != new_price
      price_histories.create!(
        price: new_price,
        recorded_at: Time.current
      )
    end
  end

  def price_history_for_chart
    if bode_flight.present?
      bode_flight.price_history_for_chart
    else
      price_histories.order(recorded_at: :asc).pluck(:recorded_at, :price).map do |recorded_at, price|
        { x: recorded_at.to_i * 1000, y: price.to_f }
      end
    end
  end

  private

  def date_in_after_date_out
    return unless date_out && date_in
    if date_in <= date_out
      errors.add(:date_in, "must be after departure date")
    end
  end
end
