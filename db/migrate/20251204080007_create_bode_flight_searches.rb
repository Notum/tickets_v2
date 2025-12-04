class CreateBodeFlightSearches < ActiveRecord::Migration[8.0]
  def change
    create_table :bode_flight_searches do |t|
      t.references :user, null: false, foreign_key: true
      t.references :bode_destination, null: false, foreign_key: true
      t.date :date_out, null: false
      t.date :date_in, null: false
      t.integer :nights
      t.decimal :price, precision: 10, scale: 2
      t.string :airline
      t.string :order_url
      t.integer :free_seats
      t.string :status, default: "pending"
      t.text :api_response
      t.datetime :priced_at

      t.timestamps
    end

    add_index :bode_flight_searches, [ :user_id, :bode_destination_id, :date_out, :date_in ], unique: true, name: "idx_bode_searches_unique"
  end
end
