class BookingSearch < ApplicationRecord
  belongs_to :user
  has_many :price_histories, class_name: "BookingPriceHistory", dependent: :destroy

  validates :city_name, presence: true
  validates :hotel_id, presence: true
  validates :hotel_name, presence: true
  validates :check_in, presence: true
  validates :check_out, presence: true
  validate :check_out_after_check_in

  scope :recent, -> { order(created_at: :desc) }
  scope :priced, -> { where(status: "priced") }
  scope :pending, -> { where(status: "pending") }

  def stay_duration
    return 0 unless check_in && check_out
    (check_out - check_in).to_i
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

  def sold_out?
    status == "sold_out"
  end

  def room_sold_out?
    status == "room_sold_out"
  end

  def record_price_if_changed(new_price, new_price_per_night, new_room_name)
    last_history = price_histories.order(recorded_at: :desc).first

    if last_history.nil? || last_history.price != new_price
      price_histories.create!(
        price: new_price,
        price_per_night: new_price_per_night,
        room_name: new_room_name,
        recorded_at: Time.current
      )
    end
  end

  def price_history_for_chart
    price_histories.order(recorded_at: :asc).pluck(:recorded_at, :price).map do |recorded_at, price|
      { x: recorded_at.to_i * 1000, y: price.to_f }
    end
  end

  def booking_url
    return hotel_url if hotel_url.present?
    "https://www.booking.com/hotel/#{hotel_id}.html?checkin=#{check_in}&checkout=#{check_out}&group_adults=#{adults}&no_rooms=#{rooms}&selected_currency=#{currency}"
  end

  def currency_symbol
    currency == "USD" ? "$" : "€"
  end

  private

  def check_out_after_check_in
    return unless check_in && check_out
    if check_out <= check_in
      errors.add(:check_out, "must be after check-in date")
    end
  end
end
