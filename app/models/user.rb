class User < ApplicationRecord
  has_many :ryanair_flight_searches, dependent: :destroy

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  before_save :downcase_email

  private

  def downcase_email
    self.email = email.downcase
  end
end
