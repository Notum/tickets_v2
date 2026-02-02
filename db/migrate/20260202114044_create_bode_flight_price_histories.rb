class CreateBodeFlightPriceHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :bode_flight_price_histories do |t|
      t.references :bode_flight, null: false, foreign_key: true
      t.decimal :price, precision: 10, scale: 2, null: false
      t.datetime :recorded_at, null: false

      t.timestamps
    end

    add_index :bode_flight_price_histories, [ :bode_flight_id, :recorded_at ], name: "idx_bode_flight_price_history_recorded"
  end
end
