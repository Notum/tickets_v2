class CreateBookingPriceHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :booking_price_histories do |t|
      t.references :booking_search, null: false, foreign_key: true
      t.decimal :price, precision: 10, scale: 2
      t.decimal :price_per_night, precision: 10, scale: 2
      t.string :room_name
      t.datetime :recorded_at, null: false

      t.timestamps
    end

    add_index :booking_price_histories, [:booking_search_id, :recorded_at], name: "idx_booking_price_history_search_recorded"
  end
end
