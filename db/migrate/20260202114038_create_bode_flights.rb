class CreateBodeFlights < ActiveRecord::Migration[8.0]
  def change
    create_table :bode_flights do |t|
      t.references :bode_destination, null: false, foreign_key: true
      t.date :date_out, null: false
      t.date :date_in, null: false
      t.integer :nights
      t.decimal :price, precision: 10, scale: 2
      t.string :airline
      t.string :order_url
      t.integer :free_seats
      t.datetime :last_seen_at

      t.timestamps
    end

    add_index :bode_flights, [ :bode_destination_id, :date_out, :date_in ], unique: true, name: "idx_bode_flights_unique"
    add_index :bode_flights, :date_out
  end
end
