class CreateRyanairPriceHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :ryanair_price_histories do |t|
      t.references :ryanair_flight_search, null: false, foreign_key: true
      t.decimal :price_out, precision: 10, scale: 2
      t.decimal :price_in, precision: 10, scale: 2
      t.decimal :total_price, precision: 10, scale: 2
      t.datetime :recorded_at, null: false

      t.timestamps
    end

    add_index :ryanair_price_histories, [ :ryanair_flight_search_id, :recorded_at ], name: "idx_price_history_search_recorded"
  end
end
