class CreateSsFlatPriceHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :ss_flat_price_histories do |t|
      t.references :ss_flat_ad, null: false, foreign_key: true
      t.decimal :price, precision: 12, scale: 2
      t.decimal :price_per_m2, precision: 10, scale: 2
      t.datetime :recorded_at, null: false

      t.timestamps
    end

    add_index :ss_flat_price_histories, [ :ss_flat_ad_id, :recorded_at ], name: "idx_ss_flat_price_history_ad_recorded"
  end
end
