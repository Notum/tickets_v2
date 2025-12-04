class CreateBodePriceHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :bode_price_histories do |t|
      t.references :bode_flight_search, null: false, foreign_key: true
      t.decimal :price, precision: 10, scale: 2
      t.datetime :recorded_at, null: false

      t.timestamps
    end

    add_index :bode_price_histories, [ :bode_flight_search_id, :recorded_at ], name: "idx_bode_price_history_search_recorded"
  end
end
