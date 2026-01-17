class User < ApplicationRecord
  CURRENCIES = %w[EUR USD].freeze

  has_many :ryanair_flight_searches, dependent: :destroy
  has_many :bode_flight_searches, dependent: :destroy
  has_many :airbaltic_flight_searches, dependent: :destroy
  has_many :norwegian_flight_searches, dependent: :destroy
  has_many :flydubai_flight_searches, dependent: :destroy
  has_many :turkish_flight_searches, dependent: :destroy
  has_many :booking_searches, dependent: :destroy

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :price_notification_threshold, presence: true,
                                           numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true, inclusion: { in: CURRENCIES }

  before_save :downcase_email

  private

  def downcase_email
    self.email = email.downcase
  end
end
