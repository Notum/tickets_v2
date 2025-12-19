class User < ApplicationRecord
  has_many :ryanair_flight_searches, dependent: :destroy
  has_many :bode_flight_searches, dependent: :destroy
  has_many :airbaltic_flight_searches, dependent: :destroy

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :price_notification_threshold, presence: true,
                                           numericality: { greater_than_or_equal_to: 0 }

  before_save :downcase_email

  private

  def downcase_email
    self.email = email.downcase
  end
end
