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

  # Flight time helpers
  def has_flight_times?
    departure_time_out.present? && arrival_time_out.present? &&
      departure_time_in.present? && arrival_time_in.present?
  end

  def outbound_flight_duration
    return nil unless departure_time_out && arrival_time_out
    duration_in_minutes = ((arrival_time_out - departure_time_out) / 60).to_i
    format_duration(duration_in_minutes)
  end

  def inbound_flight_duration
    return nil unless departure_time_in && arrival_time_in
    duration_in_minutes = ((arrival_time_in - departure_time_in) / 60).to_i
    format_duration(duration_in_minutes)
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

  def format_duration(minutes)
    hours = minutes / 60
    mins = minutes % 60
    "#{hours}h #{mins}m"
  end
end
