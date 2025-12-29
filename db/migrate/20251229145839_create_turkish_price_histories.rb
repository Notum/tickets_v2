class CreateTurkishPriceHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :turkish_price_histories do |t|
      t.references :turkish_flight_search, null: false, foreign_key: true
      t.decimal :price_out, precision: 10, scale: 2
      t.decimal :price_in, precision: 10, scale: 2
      t.decimal :total_price, precision: 10, scale: 2
      t.datetime :recorded_at, null: false

      t.timestamps
    end

    add_index :turkish_price_histories, [:turkish_flight_search_id, :recorded_at],
              name: "idx_turkish_price_history_search_recorded"
  end
end
