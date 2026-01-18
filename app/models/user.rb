class User < ApplicationRecord
  CURRENCIES = %w[EUR USD].freeze

  has_many :ryanair_flight_searches, dependent: :destroy
  has_many :bode_flight_searches, dependent: :destroy
  has_many :airbaltic_flight_searches, dependent: :destroy
  has_many :norwegian_flight_searches, dependent: :destroy
  has_many :flydubai_flight_searches, dependent: :destroy
  has_many :turkish_flight_searches, dependent: :destroy
  has_many :booking_searches, dependent: :destroy
  has_many :ss_flat_follows, dependent: :destroy
  has_many :followed_flats, through: :ss_flat_follows, source: :ss_flat_ad
  has_many :ss_house_follows, dependent: :destroy
  has_many :followed_houses, through: :ss_house_follows, source: :ss_house_ad

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
