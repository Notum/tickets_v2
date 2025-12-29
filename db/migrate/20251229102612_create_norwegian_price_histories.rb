class CreateNorwegianPriceHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :norwegian_price_histories do |t|
      t.references :norwegian_flight_search, null: false, foreign_key: true
      t.decimal :price_out, precision: 10, scale: 2
      t.decimal :price_in, precision: 10, scale: 2
      t.decimal :total_price, precision: 10, scale: 2
      t.datetime :recorded_at, null: false

      t.timestamps
    end

    add_index :norwegian_price_histories, [:norwegian_flight_search_id, :recorded_at],
              name: "idx_norwegian_price_history_search_recorded"
  end
end
