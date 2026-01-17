class CreateBookingSearches < ActiveRecord::Migration[8.0]
  def change
    create_table :booking_searches do |t|
      t.references :user, null: false, foreign_key: true

      # Location info
      t.string :city_name, null: false
      t.string :country_name

      # Hotel info from Booking.com
      t.string :hotel_id, null: false
      t.string :hotel_name, null: false
      t.string :hotel_url

      # Search parameters
      t.date :check_in, null: false
      t.date :check_out, null: false
      t.integer :adults, default: 2, null: false
      t.integer :rooms, default: 1, null: false
      t.string :currency, default: "EUR", null: false

      # Price data
      t.string :room_name
      t.decimal :price, precision: 10, scale: 2
      t.decimal :price_per_night, precision: 10, scale: 2

      # Status tracking
      t.string :status, default: "pending"
      t.text :api_response
      t.datetime :priced_at

      t.timestamps
    end

    add_index :booking_searches, :hotel_id
    add_index :booking_searches, [:user_id, :hotel_id, :check_in, :check_out], unique: true, name: "idx_booking_unique_search"
  end
end
