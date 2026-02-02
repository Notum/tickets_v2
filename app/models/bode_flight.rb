class BodeFlight < ApplicationRecord
  belongs_to :bode_destination
  has_many :bode_flight_searches, dependent: :nullify
  has_many :price_histories, class_name: "BodeFlightPriceHistory", dependent: :destroy

  scope :active, -> { where("last_seen_at > ?", 24.hours.ago) }
  scope :for_destination, ->(destination) { where(bode_destination: destination) }
  scope :future, -> { where("date_out >= ?", Date.current) }
  scope :by_departure, -> { order(:date_out) }

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
    price_histories.order(recorded_at: :asc).pluck(:recorded_at, :price).map do |recorded_at, price|
      { x: recorded_at.to_i * 1000, y: price.to_f }
    end
  end
end
